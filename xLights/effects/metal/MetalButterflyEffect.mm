
#include "MetalComputeUtilities.hpp"
#include "MetalButterflyEffect.hpp"
#include "ButterflyTypes.h"

#include "../../RenderBuffer.h"

#include <array>

class MetalButterflyEffectData {
public:
    MetalButterflyEffectData() {
        for (auto &f : functions) {
            f = nil;
        }
        functions[1] = MetalComputeUtilities::INSTANCE.FindComputeFunction("ButterflyEffectStyle1");
        functions[2] = MetalComputeUtilities::INSTANCE.FindComputeFunction("ButterflyEffectStyle2");
        functions[3] = MetalComputeUtilities::INSTANCE.FindComputeFunction("ButterflyEffectStyle3");
        functions[4] = MetalComputeUtilities::INSTANCE.FindComputeFunction("ButterflyEffectStyle4");
        functions[5] = MetalComputeUtilities::INSTANCE.FindComputeFunction("ButterflyEffectStyle5");
    }
    ~MetalButterflyEffectData() {
        for (auto &f : functions) {
            if (f != nil) {
                [f release];
            }
        }
    }
    bool canRenderStyle(int style) {
        return style < functions.size() && functions[style] != nil;
    }

    bool Render(int style, ButterflyData &data, RenderBuffer &buffer) {
        if (@available(macOS 10.13, *)) {
            @autoreleasepool {
                MetalRenderBufferComputeData * rbcd = MetalRenderBufferComputeData::getMetalRenderBufferComputeData(&buffer);

                id<MTLCommandBuffer> commandBuffer = rbcd->getCommandBuffer();
                if (commandBuffer == nil) {
                    return false;
                }
                id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
                if (computeEncoder == nil) {
                    commandBuffer = nil;
                    return false;
                }
                [computeEncoder setLabel:@"ButterflyEffect"];
                [computeEncoder setComputePipelineState:functions[style]];

                NSInteger dataSize = sizeof(data);
                [computeEncoder setBytes:&data length:dataSize atIndex:0];

                
                id<MTLBuffer> bufferResult = rbcd->getPixelBuffer();
                if (bufferResult == nil) {
                    computeEncoder = nil;
                    commandBuffer = nil;
                    return false;
                }

                [computeEncoder setBuffer:bufferResult offset:0 atIndex:1];

                NSInteger maxThreads = functions[style].maxTotalThreadsPerThreadgroup;
                dataSize = data.width * data.height;
                NSInteger threads = std::min(dataSize, maxThreads);
                MTLSize gridSize = MTLSizeMake(dataSize, 1, 1);
                MTLSize threadsPerThreadgroup = MTLSizeMake(threads, 1, 1);

                [computeEncoder dispatchThreads:gridSize
                          threadsPerThreadgroup:threadsPerThreadgroup];

                [computeEncoder endEncoding];
            }
            return true;
        }
        return false;
    }
    std::array<id<MTLComputePipelineState>, 11> functions;
};

MetalButterflyEffect::MetalButterflyEffect(int i) : ButterflyEffect(i) {
    data = new MetalButterflyEffectData();
}
MetalButterflyEffect::~MetalButterflyEffect() {
    if (data) {
        delete data;
    }
}


void MetalButterflyEffect::Render(Effect *effect, SettingsMap &SettingsMap, RenderBuffer &buffer) {
    MetalRenderBufferComputeData * rbcd = MetalRenderBufferComputeData::getMetalRenderBufferComputeData(&buffer);
    int Style = SettingsMap.GetInt("SLIDER_Butterfly_Style", 1);

    //currently just  Style 1 is GPU enabled
    if (rbcd == nullptr || !data->canRenderStyle(Style)) {
        ButterflyEffect::Render(effect, SettingsMap, buffer);
        return;
    }

    float oset = buffer.GetEffectTimeIntervalPosition();
    const int Chunks = GetValueCurveInt("Butterfly_Chunks", 1, SettingsMap, oset, BUTTERFLY_CHUNKS_MIN, BUTTERFLY_CHUNKS_MAX, buffer.GetStartTimeMS(), buffer.GetEndTimeMS());
    int Skip = GetValueCurveInt("Butterfly_Skip", 2, SettingsMap, oset, BUTTERFLY_SKIP_MIN, BUTTERFLY_SKIP_MAX, buffer.GetStartTimeMS(), buffer.GetEndTimeMS());
    int butterFlySpeed = GetValueCurveInt("Butterfly_Speed", 10, SettingsMap, oset, BUTTERFLY_SPEED_MIN, BUTTERFLY_SPEED_MAX, buffer.GetStartTimeMS(), buffer.GetEndTimeMS());

    std::string colors = SettingsMap["CHOICE_Butterfly_Colors"];
    int ColorScheme = (colors == "Palette") ? 1 : 0;

    int ButterflyDirection = SettingsMap["CHOICE_Butterfly_Direction"] == "Reverse" ? 1 : 0;

    //const int maxframe=buffer.BufferHt*2;
    const int curState = (buffer.curPeriod - buffer.curEffStartPer) * butterFlySpeed * buffer.frameTimeInMs / 50;
    //const int frame=(buffer.BufferHt * curState / 200)%maxframe;
    //const size_t colorcnt=buffer.GetColorCount();
    const float offset = (ButterflyDirection==1 ? -1.0 : 1.0) * float(curState)/200.0f;
    //const int xc=buffer.BufferWi/2;
    //const int yc=buffer.BufferHt/2;
    //int block = buffer.BufferHt * buffer.BufferWi > 100 ? 1 : -1;

    ButterflyData rdata;
    rdata.width = buffer.BufferWi;
    rdata.height = buffer.BufferHt;
    rdata.curState = curState;
    rdata.numColors = buffer.palette.Size();
    rdata.offset = offset;
    rdata.chunks = Chunks;
    rdata.skip = Skip;
    rdata.colorScheme = ColorScheme;
    for (int x = 0; x < rdata.numColors; x++) {
        rdata.colors[x] = buffer.palette.GetColor(x).asChar4();
    }


    if (!data->Render(Style, rdata, buffer)) {
        ButterflyEffect::Render(effect, SettingsMap, buffer);
    }
}