#pragma once

/***************************************************************
 * This source files comes from the xLights project
 * https://www.xlights.org
 * https://github.com/xLightsSequencer/xLights
 * See the github commit history for a record of contributing
 * developers.
 * Copyright claimed based on commit dates recorded in Github
 * License: https://github.com/xLightsSequencer/xLights/blob/master/License.txt
 **************************************************************/

// iPadRenderContext — RenderContext for loading, rendering, and displaying
// sequences on iPad.  Includes RenderEngine for effect rendering.

#include "render/RenderContext.h"
#include "render/SequenceData.h"
#include "render/SequenceElements.h"
#include "render/SequenceFile.h"
#include "render/SequenceViewManager.h"
#include "render/RenderEngine.h"
#include "render/RenderCache.h"
#include "render/IRenderProgressSink.h"
#include "effects/EffectManager.h"
#include "outputs/OutputManager.h"
#include "models/ModelManager.h"
#include "models/OutputModelManager.h"
#include "models/ViewObjectManager.h"
#include "utils/JobPool.h"

#include <list>
#include <memory>
#include <optional>
#include <string>

class iPadRenderContext : public RenderContext {
public:
    iPadRenderContext();
    ~iPadRenderContext() override;

    // Show folder management
    bool LoadShowFolder(const std::string& showDir);
    bool LoadShowFolder(const std::string& showDir,
                        const std::list<std::string>& mediaFolders);
    const std::string& GetShowDirectory() const override { return _showDir; }

    // Sequence management
    bool OpenSequence(const std::string& path);
    void CloseSequence();

    // RenderContext implementation
    const std::string& GetFseqDirectory() const override { return _showDir; }
    const std::list<std::string>& GetMediaFolders() const override { return _mediaFolders; }
    bool IsInShowFolder(const std::string& file) const override;
    bool IsInShowOrMediaFolder(const std::string& file) const override;
    // Copy `file` into `<showDir>/<subdirectory>`, returning the final
    // absolute path. Appends `_N` on name collision unless `reuse` and
    // the existing file's contents already match. Empty string on
    // failure (no show folder configured, copy error).
    std::string MoveToShowFolder(const std::string& file,
                                  const std::string& subdirectory,
                                  bool reuse) override;

    // Same as MoveToShowFolder but the destination root is one of the
    // configured media folders (`mediaFolderPath` must appear in
    // `_mediaFolders` or we refuse). Used by the iPad fileImporter
    // "destination: Media Folder X" branch.
    std::string CopyToMediaFolder(const std::string& file,
                                   const std::string& mediaFolderPath,
                                   const std::string& subdirectory);
    std::string MakeRelativePath(const std::string& file) const override;

    SequenceElements& GetSequenceElements() override { return _sequenceElements; }
    SequenceViewManager& GetSequenceViewManager() { return _viewsManager; }
    bool IsSequenceLoaded() const override { return _sequenceFile && _sequenceFile->IsOpen(); }
    AudioManager* GetCurrentMediaManager() const override;
    const std::string& GetHeaderInfo(HEADER_INFO_TYPES type) const override;

    Model* GetModel(const std::string& name) const override;
    EffectManager& GetEffectManager() override { return _effectManager; }
    OutputModelManager* GetOutputModelManager() override { return &_outputModelManager; }

    bool AbortRender(int maxTimeMs = 60000) override;
    void RenderEffectForModel(const std::string& model, int startms, int endms, bool clear) override;
    TimingElement* AddTimingElement(const std::string& name,
                                    const std::string& subType = "") override;
    void SuspendAutoSave(bool) override {}
    bool IsLowDefinitionRender() const override { return true; }

    // Rendering
    void RenderAll();
    void SetModelColors(int frameMS);
    SequenceData& GetSequenceData() { return _sequenceData; }
    bool IsRenderDone();

    // Memory-pressure response. Called from Swift when the system signals
    // memory warning / critical. Aborts any in-flight render and purges the
    // render cache so we don't hold onto frame buffers we no longer need.
    void HandleMemoryWarning();
    void HandleMemoryCritical();

    // Accessors
    OutputManager& GetOutputManager() { return _outputManager; }
    ModelManager& GetModelManager() { return *_modelManager; }
    ViewObjectManager& GetAllObjects() { return *_viewObjectManager; }
    SequenceFile* GetSequenceFile() { return _sequenceFile.get(); }
    // Virtual preview canvas size from <settings><previewWidth/Height>
    // in xlights_rgbeffects.xml, defaulted to desktop's 1280×720 when
    // absent. Consumed by iPadModelPreview in House Preview mode so the
    // 2D ortho projection maps world coords onto pixel coords the same
    // way desktop does.
    int GetPreviewWidth() const { return _previewWidth; }
    int GetPreviewHeight() const { return _previewHeight; }

    // <settings><Display2DCenter0 value="1"/>. When set, desktop places
    // world X=0 at the horizontal centre of the preview (shows with
    // models laid out around a centered origin, e.g. -600..+600 rather
    // than 0..1200). Ignoring this flag was the cause of the House
    // Preview rendering blank for center-origin shows.
    bool GetDisplay2DCenter0() const { return _display2DCenter0; }

    // House Preview background image + brightness/alpha/scale — values
    // come from `<settings>` in xlights_rgbeffects.xml and are read-only
    // on iPad (editing lives in the desktop Layout panel, out of iPad
    // scope). Path is FixFile-resolved against the show directory; empty
    // string means "no background".
    const std::string& GetBackgroundImage() const { return _backgroundImage; }
    int GetBackgroundBrightness() const { return _backgroundBrightness; }
    int GetBackgroundAlpha() const { return _backgroundAlpha; }
    bool GetScaleBackgroundImage() const { return _scaleBackgroundImage; }

    // Model pixel data for a given frame — returns (x, y, r, g, b) tuples
    struct PixelData {
        float x, y;
        uint8_t r, g, b;
    };
    std::vector<PixelData> GetModelPixels(const std::string& modelName, int frameMS);
    std::vector<PixelData> GetAllModelPixels(int frameMS);

private:
    std::string _showDir;
    std::list<std::string> _mediaFolders;

    OutputManager _outputManager;
    OutputModelManager _outputModelManager;
    std::unique_ptr<ModelManager> _modelManager;
    std::unique_ptr<ViewObjectManager> _viewObjectManager;
    EffectManager _effectManager;
    SequenceElements _sequenceElements;
    SequenceViewManager _viewsManager;
    std::unique_ptr<SequenceFile> _sequenceFile;
    std::optional<pugi::xml_document> _sequenceDoc;

    // Rendering
    SequenceData _sequenceData;
    std::unique_ptr<JobPool> _jobPool;
    RenderCache _renderCache;
    std::unique_ptr<RenderEngine> _renderEngine;
    unsigned int _modelsChangeCount = 0;

    // Virtual preview canvas size — desktop defaults.
    int _previewWidth = 1280;
    int _previewHeight = 720;
    bool _display2DCenter0 = false;

    std::string _backgroundImage;
    int _backgroundBrightness = 100;
    int _backgroundAlpha = 100;
    bool _scaleBackgroundImage = false;
};
