/***************************************************************
 * This source files comes from the xLights project
 * https://www.xlights.org
 * https://github.com/xLightsSequencer/xLights
 * See the github commit history for a record of contributing
 * developers.
 * Copyright claimed based on commit dates recorded in Github
 * License: https://github.com/xLightsSequencer/xLights/blob/master/License.txt
 **************************************************************/

#import "XLMetalBridge.h"
#import "../Bridge/XLSequenceDocument.h"
#include "xlStandaloneMetalCanvas.h"
#include "iPadModelPreview.h"
#include "../Bridge/iPadRenderContext.h"
#include "models/Model.h"
#include "models/ModelManager.h"
#include "models/ViewObject.h"
#include "models/ViewObjectManager.h"
#include "render/ViewpointMgr.h"
#include "graphics/xlGraphicsContext.h"
#include "utils/xlImage.h"
#include "graphics/metal/xlMetalGraphicsContext.h"

#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>

#include <cstring>
#include <memory>
#include <string>

#define PIXEL_SIZE_ON_DIALOGS 2.0

@interface XLMetalBridge ()
- (void)drawBackgroundWithContext:(iPadRenderContext*)ctx
                      graphicsCtx:(xlGraphicsContext*)graphicsCtx
                        solidProg:(xlGraphicsProgram*)solidProg;
@end

@implementation XLMetalBridge {
    std::unique_ptr<xlStandaloneMetalCanvas> _canvas;
    std::unique_ptr<iPadModelPreview> _preview;
    std::string _previewModel;   // set via setPreviewModel:
    BOOL _isModelPreview;        // YES = single-model pane; NO = full house
    BOOL _showViewObjects;       // House Preview view-object visibility toggle
    // Cached background image — loaded once per path change, reused across
    // frames. Texture ownership is manual because xlTexture has no
    // unique_ptr-friendly deleter in the public header; released in
    // dealloc. The raw xlImage bytes are kept so we can re-upload into a
    // fresh texture if we ever need to invalidate without re-decoding.
    xlTexture* _bgTexture;
    std::string _bgLoadedPath;
    int _bgImageWidth;
    int _bgImageHeight;
}

- (instancetype)initWithName:(NSString*)name {
    self = [super init];
    if (self) {
        // is3d=true so the canvas allocates a depth buffer + MSAA target.
        // MeshObject (and other view-object renderers) enable depth testing
        // in drawMeshSolids, which crashes validation if no depth attachment
        // is bound. Depth is harmless for existing 2D model rendering.
        std::string nameStr = std::string([name UTF8String]);
        _canvas = std::make_unique<xlStandaloneMetalCanvas>(nameStr, true);
        _preview = std::make_unique<iPadModelPreview>(_canvas.get());
        _preview->SetName(nameStr);
        _isModelPreview = [name isEqualToString:@"ModelPreview"];
        _showViewObjects = YES;
        _bgTexture = nullptr;
        _bgImageWidth = 0;
        _bgImageHeight = 0;
        // Model preview defaults to 2D (fit-to-window single-model view); the
        // House preview keeps the 3D default.
        if (_isModelPreview) {
            _preview->SetIs3D(false);
        }
    }
    return self;
}

- (void)dealloc {
    delete _bgTexture;
    _bgTexture = nullptr;
}

/// Load an image file into an xlImage using ImageIO (CGImageSource). The
/// returned pointer is nullptr on failure. Mirrors the
/// CGImageSourceCreateWithURL path in XLiPadInit.mm — RGBA interleaved
/// bytes so they copy straight into an xlImage buffer.
static std::unique_ptr<xlImage> LoadImageFile(const std::string& path, int& outW, int& outH) {
    outW = outH = 0;
    if (path.empty()) return nullptr;

    NSString* nsPath = [NSString stringWithUTF8String:path.c_str()];
    NSURL* url = [NSURL fileURLWithPath:nsPath];
    CGImageSourceRef src = CGImageSourceCreateWithURL((__bridge CFURLRef)url, nullptr);
    if (!src) return nullptr;

    CGImageRef cgImg = CGImageSourceCreateImageAtIndex(src, 0, nullptr);
    CFRelease(src);
    if (!cgImg) return nullptr;

    int w = (int)CGImageGetWidth(cgImg);
    int h = (int)CGImageGetHeight(cgImg);
    if (w <= 0 || h <= 0) {
        CGImageRelease(cgImg);
        return nullptr;
    }

    std::unique_ptr<uint8_t[]> rgba(new uint8_t[(size_t)w * h * 4]());
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(rgba.get(), w, h, 8, w * 4, cs,
                                             kCGImageAlphaPremultipliedLast
                                             | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(cs);
    if (!ctx) {
        CGImageRelease(cgImg);
        return nullptr;
    }
    CGContextSetBlendMode(ctx, kCGBlendModeCopy);
    CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), cgImg);
    CGContextRelease(ctx);
    CGImageRelease(cgImg);

    auto img = std::make_unique<xlImage>(w, h);
    std::memcpy(img->GetData(), rgba.get(), (size_t)w * h * 4);
    outW = w;
    outH = h;
    return img;
}

- (void)attachLayer:(CAMetalLayer*)layer {
    _canvas->setMetalLayer(layer);
}

- (void)setDrawableSize:(CGSize)size scale:(CGFloat)scale {
    _canvas->setSize((int)size.width, (int)size.height);
    _canvas->setScaleFactor(scale);
}

- (void)setPreviewModel:(NSString*)modelName {
    if (modelName == nil || modelName.length == 0) {
        _previewModel.clear();
    } else {
        _previewModel = std::string([modelName UTF8String]);
    }
    if (_preview) {
        _preview->SetCurrentModel(_previewModel);
    }
}

// Visual zoom factor — > 1 = zoomed in (scene appears larger), < 1 = zoomed out.
// The underlying PreviewCamera::zoom is a raw multiplier on the view-matrix
// distance (3D) or an inverse on the ortho half-width (2D), with opposite
// directions in the two modes (see ViewpointMgr.cpp GetViewMatrix and
// ModelPreview::SetZoomDelta). Normalising through a visual factor here lets
// the Swift gesture code stay mode-agnostic.
- (void)setCameraZoom:(float)zoom {
    if (!_preview) return;
    float factor = zoom <= 0.0f ? 1.0f : zoom;
    float raw = _preview->Is3D() ? (1.0f / factor) : factor;
    _preview->ActiveCamera().SetZoom(raw);
}

- (float)cameraZoom {
    if (!_preview) return 1.0f;
    float raw = _preview->ActiveCamera().GetZoom();
    if (raw <= 0.0f) return 1.0f;
    return _preview->Is3D() ? (1.0f / raw) : raw;
}

- (void)setCameraPanX:(float)x panY:(float)y {
    if (!_preview) return;
    _preview->ActiveCamera().SetPanX(x);
    _preview->ActiveCamera().SetPanY(y);
}

- (void)offsetCameraPanX:(float)dx panY:(float)dy {
    if (!_preview) return;
    auto& cam = _preview->ActiveCamera();
    cam.SetPanX(cam.GetPanX() + dx);
    cam.SetPanY(cam.GetPanY() + dy);
}

- (float)cameraPanX {
    return _preview ? _preview->ActiveCamera().GetPanX() : 0.0f;
}

- (float)cameraPanY {
    return _preview ? _preview->ActiveCamera().GetPanY() : 0.0f;
}

- (void)setCameraAngleX:(float)ax angleY:(float)ay {
    if (!_preview) return;
    _preview->ActiveCamera().SetAngleX(ax);
    _preview->ActiveCamera().SetAngleY(ay);
}

- (void)offsetCameraAngleX:(float)dx angleY:(float)dy {
    if (!_preview) return;
    auto& cam = _preview->ActiveCamera();
    cam.SetAngleX(cam.GetAngleX() + dx);
    cam.SetAngleY(cam.GetAngleY() + dy);
}

- (float)cameraAngleX {
    return _preview ? _preview->ActiveCamera().GetAngleX() : 0.0f;
}

- (float)cameraAngleY {
    return _preview ? _preview->ActiveCamera().GetAngleY() : 0.0f;
}

- (void)resetCamera {
    if (_preview) _preview->ResetCamera();
}

- (void)setIs3D:(BOOL)is3d {
    if (_preview) _preview->SetIs3D(is3d ? true : false);
}

- (BOOL)is3D {
    return (_preview && _preview->Is3D()) ? YES : NO;
}

- (void)setShowViewObjects:(BOOL)show {
    _showViewObjects = show;
}

- (BOOL)showViewObjects {
    return _showViewObjects;
}

- (void)drawModelsForDocument:(XLSequenceDocument*)doc atMS:(int)frameMS pointSize:(float)pointSize {
    if (_canvas->getMetalLayer() == nil) return;
    if (_canvas->getWidth() == 0 || _canvas->getHeight() == 0) return;

    iPadRenderContext* ctx = static_cast<iPadRenderContext*>([doc renderContext]);
    if (!ctx) return;

    // Set channel data on all models for this frame
    ctx->SetModelColors(frameMS);

    // Set current frame time so models can query it
    _preview->SetCurrentFrameTime(frameMS);

    // House Preview needs a virtual canvas so the 2D ortho projection in
    // iPadModelPreview::StartDrawing maps world coords (model positions
    // saved in xlights_rgbeffects.xml against previewWidth × previewHeight)
    // onto pixel coords at the current pane size. Without this, scale2d
    // stays 1 and models at e.g. (600, 400) land off-screen in 2D mode.
    // Model Preview stays at 0×0 so DisplayEffectOnWindow's own
    // fit-to-window scaling still applies.
    if (_isModelPreview) {
        _preview->SetVirtualCanvasSize(0, 0);
        _preview->SetCenter2D0(false);
    } else {
        _preview->SetVirtualCanvasSize(ctx->GetPreviewWidth(),
                                       ctx->GetPreviewHeight());
        _preview->SetCenter2D0(ctx->GetDisplay2DCenter0());
    }

    // Start a single drawing pass — acquires one drawable
    if (!_preview->StartDrawing(pointSize)) return;

    auto* graphicsCtx = _preview->getCurrentGraphicsContext();
    auto* solidProg = _preview->getCurrentSolidProgram();
    auto* transparentProg = _preview->getCurrentTransparentProgram();
    auto* solidVOProg = _preview->getCurrentSolidViewObjectProgram();
    auto* transparentVOProg = _preview->getCurrentTransparentViewObjectProgram();

    if (_isModelPreview) {
        // Model Preview pane: draw ONLY the selected model (or group), fit-to-window,
        // ignoring its world placement. Mirrors desktop ModelPreview's 2D
        // single-model path (ModelPreview.cpp:538): DisplayEffectOnWindow
        // applies its own scale + centering to fit the model to the preview
        // dimensions rather than using ModelScreenLocation. ModelGroups build
        // pseudo-nodes sized to their default buffer style, so the same call
        // works for groups — constituent models appear at their group-buffer
        // positions, not their world positions. If nothing is selected, the
        // pane stays black (clear-only) — we intentionally do NOT fall through
        // to the full-house path.
        if (!_previewModel.empty()) {
            auto& models = ctx->GetModelManager();
            Model* m = models[_previewModel];
            if (m) {
                m->DisplayEffectOnWindow(_preview.get(), pointSize);
            }
        }
    } else {
        // House Preview: every model at its world position, view objects on top.
        // Sort models back-to-front by camera-space Z of their world centre so
        // alpha-blended pixels from one model composite over models behind them.
        // Matches ModelPreview::RenderModels on desktop.

        // Background image — only rendered in 2D mode, matching desktop
        // (ModelPreview.cpp:1411). brightness/alpha/scale settings are
        // read from xlights_rgbeffects.xml; iPad never edits them. The
        // texture is cached between frames and only rebuilt when the
        // show-folder path changes. Gated behind the same "View Objects"
        // toggle as the house-mesh/ground/terrain loop below, so users
        // have one switch that hides every non-pixel scene element
        // (background, view objects, and once Phase D-8 lands, the 2D
        // grid and bounding-box overlays too).
        if (!_preview->Is3D() && _showViewObjects) {
            [self drawBackgroundWithContext:ctx graphicsCtx:graphicsCtx solidProg:solidProg];
        }

        auto models = ctx->GetModelManager().GetModels();
        const glm::mat4& viewMatrix = _preview->GetViewMatrix();
        std::vector<std::pair<Model*, float>> keyed;
        keyed.reserve(models.size());
        for (auto& [name, model] : models) {
            if (model->GetDisplayAs() == DisplayAsType::ModelGroup) continue;
            glm::vec3 c = model->GetModelScreenLocation().GetCenterPosition();
            float z = (viewMatrix * glm::vec4(c, 1.0f)).z;
            keyed.emplace_back(model, z);
        }
        std::stable_sort(keyed.begin(), keyed.end(),
                         [](const std::pair<Model*, float>& a, const std::pair<Model*, float>& b) {
                             return a.second < b.second;
                         });
        const bool is3d = _preview->Is3D();
        for (const auto& [model, z] : keyed) {
            // Pass the current 2D/3D state rather than a hardcoded true —
            // it drives PrepareToDraw's draw_3d flag (which controls
            // worldPos_z usage and the 2D perspective rotation) and the
            // uiCaches key. Telling a 2D render "we're 3D" made
            // BoxedScreenLocation place models at their saved Z, and with
            // ortho left-handed near=1/far=0 any non-zero Z put geometry
            // outside the frustum.
            model->DisplayModelOnWindow(_preview.get(), graphicsCtx, solidProg, transparentProg,
                                         is3d, nullptr, false, false, false, 0, nullptr);
        }

        // View objects (house meshes, ground images, gridlines, terrain).
        // Skipped entirely when the user toggles them off via the preview
        // controls — useful to declutter during pixel-level inspection.
        if (_showViewObjects) {
            auto& allObjects = ctx->GetAllObjects();
            for (auto it = allObjects.begin(); it != allObjects.end(); ++it) {
                ViewObject* vo = it->second;
                if (vo) {
                    vo->Draw(_preview.get(), graphicsCtx, solidVOProg, transparentVOProg, false);
                }
            }
        }
    }

    // Finish and present
    _preview->EndDrawing(true);
}

// Lazy-load + enqueue the 2D background draw. No-op when no path is
// configured or the texture fails to load. Draw math mirrors
// ModelPreview.cpp:1431 — image sits in world coords 0..virtualW by
// 0..virtualH (optionally scaled to preserve aspect when !scaleImage),
// shifted by -virtualW/2 in X when Display2DCenter0 is on. Brightness
// stays 0..100; alpha is percent → 0..255.
- (void)drawBackgroundWithContext:(iPadRenderContext*)rctx
                      graphicsCtx:(xlGraphicsContext*)gctx
                        solidProg:(xlGraphicsProgram*)solidProg {
    const std::string& path = rctx->GetBackgroundImage();
    if (path.empty() || !gctx || !solidProg) return;

    if (_bgTexture == nullptr || path != _bgLoadedPath) {
        int w = 0, h = 0;
        auto img = LoadImageFile(path, w, h);
        if (!img || w <= 0 || h <= 0) {
            return;
        }
        delete _bgTexture;
        _bgTexture = gctx->createTexture(*img, path, /* finalize */ true);
        _bgLoadedPath = path;
        _bgImageWidth = w;
        _bgImageHeight = h;
    }
    if (!_bgTexture) return;

    const int virtualW = rctx->GetPreviewWidth();
    const int virtualH = rctx->GetPreviewHeight();
    const bool scaleImage = rctx->GetScaleBackgroundImage();
    const bool center0 = rctx->GetDisplay2DCenter0();
    const int brightness = rctx->GetBackgroundBrightness();
    const int alpha = (int)((rctx->GetBackgroundAlpha() * 255) / 100);

    float scaleh = 1.0f;
    float scalew = 1.0f;
    if (!scaleImage && virtualW > 0 && virtualH > 0 && _bgImageWidth > 0 && _bgImageHeight > 0) {
        // Preserve the image's aspect ratio inside the virtual preview
        // rectangle — the axis that would overflow gets pulled back in.
        float nscaleh = (float)_bgImageHeight / (float)virtualH;
        float nscalew = (float)_bgImageWidth / (float)virtualW;
        if (nscaleh == 0) nscaleh = 1.0f;
        if (nscalew == 0) nscalew = 1.0f;
        if (nscalew < nscaleh) {
            scaleh = 1.0f;
            scalew = nscalew / nscaleh;
        } else {
            scaleh = nscaleh / nscalew;
            scalew = 1.0f;
        }
    }
    float x = 0.0f;
    if (center0) {
        x = -(float)virtualW / 2.0f;
    }
    const float x2 = x + (float)virtualW * scalew;
    const float y2 = (float)virtualH * scaleh;

    xlTexture* tex = _bgTexture;
    solidProg->addStep([tex, x, y2, x2, brightness, alpha](xlGraphicsContext* c) {
        c->drawTexture(tex, x, y2, x2, 0.0f,
                       0.0f, 0.0f, 1.0f, 1.0f,
                       /* smoothScale */ true,
                       brightness, alpha);
    });
}

@end
