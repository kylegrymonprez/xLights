/***************************************************************
 * This source files comes from the xLights project
 * https://www.xlights.org
 * https://github.com/xLightsSequencer/xLights
 * See the github commit history for a record of contributing
 * developers.
 * Copyright claimed based on commit dates recorded in Github
 * License: https://github.com/xLightsSequencer/xLights/blob/master/License.txt
 **************************************************************/

#include "MovingHeadTestEngine.h"

#include "OutputManager.h"
#include "../models/DMX/DmxMovingHeadComm.h"
#include "../models/DMX/DmxMovingHeadAdv.h"
#include "../models/DMX/DmxMotor.h"
#include "../models/DMX/DmxColorAbility.h"
#include "../models/DMX/DmxShutterAbility.h"
#include "../models/DMX/DmxDimmerAbility.h"
#include "../models/DMX/MovingHeads/MhFeature.h"
#include "../models/DMX/MovingHeads/MhChannel.h"

#include <algorithm>

#include <spdlog/fmt/fmt.h>

namespace xltest {

namespace {
// Mirrors MovingHeadEffect::WriteCmdToPixel's coarse/fine split: the top
// byte always goes to the coarse channel (relied on for 8-bit-only motors,
// where there is no fine channel and only the coarse byte is sent), the
// bottom byte goes to the fine channel when the motor has one.
void WriteMotorCommand(DmxMotor* motor, float angleDegrees, xlColorVector& pixels)
{
    if (motor == nullptr) {
        return;
    }
    int cmd = motor->ConvertPostoCmd(angleDegrees);
    uint8_t msb, lsb;
    MovingHeadTestEngine::SplitMotorCommand(cmd, msb, lsb);
    int coarse = motor->GetChannelCoarse();
    int fine = motor->GetChannelFine();
    if (coarse > 0 && coarse <= (int)pixels.size()) {
        pixels[coarse - 1] = xlColor(msb, msb, msb);
    }
    if (fine > 0 && fine <= (int)pixels.size()) {
        pixels[fine - 1] = xlColor(lsb, lsb, lsb);
    }
}
} // namespace

void MovingHeadTestEngine::SplitMotorCommand(int cmd, uint8_t& coarseByte, uint8_t& fineByte)
{
    coarseByte = (uint8_t)((cmd >> 8) & 0xFF);
    fineByte = (uint8_t)(cmd & 0xFF);
}

MHTestState MovingHeadTestEngine::HomeState(const DmxMovingHeadComm* fixture)
{
    MHTestState state;
    state.dimmer = 255;
    state.panDegrees = 90.0f;
    state.tiltDegrees = 180.0f;
    state.shutterValue = (fixture != nullptr && fixture->HasShutterAbility())
        ? fixture->GetShutterAbility()->GetShutterOnValue()
        : 255;

    // CMY(W) is subtractive: (0,0,0) subtracts nothing, giving a white beam,
    // the same "beam visible" default as RGB(W)'s (255,255,255).
    if (fixture != nullptr && fixture->HasColorAbility() &&
        fixture->GetColorAbility()->GetColorType() == DmxColorAbility::DMX_COLOR_TYPE::DMX_COLOR_CMYW) {
        state.rgbColor = xlColor(0, 0, 0);
    } else {
        state.rgbColor = xlColor(255, 255, 255);
    }
    return state;
}

std::vector<uint8_t> MovingHeadTestEngine::BuildFrameBytes(const DmxMovingHeadComm* fixture, const MHTestState& state) const
{
    xlColorVector pixels(std::max(0, fixture->GetDmxChannelCount()), xlColor(0, 0, 0));

    WriteMotorCommand(fixture->GetPanMotor(), state.panDegrees, pixels);
    WriteMotorCommand(fixture->GetTiltMotor(), state.tiltDegrees, pixels);

    if (fixture->HasColorAbility()) {
        // SetColorPixels() is polymorphic per concrete ability - RGB(W)/
        // CMY(W) decompose state.rgbColor channel-by-channel, and a color
        // wheel does its own nearest-hue match against this fixture's own
        // wheel slots. One call covers every color ability type correctly.
        fixture->GetColorAbility()->SetColorPixels(state.rgbColor, pixels);
    }

    if (fixture->HasDimmerAbility()) {
        int chan = fixture->GetDimmerAbility()->GetDimmerChannel();
        if (chan > 0 && chan <= (int)pixels.size()) {
            uint8_t v = (uint8_t)std::clamp(state.dimmer, 0, 255);
            pixels[chan - 1] = xlColor(v, v, v);
        }
    }

    if (fixture->HasShutterAbility()) {
        int chan = fixture->GetShutterAbility()->GetShutterChannel();
        if (chan > 0 && chan <= (int)pixels.size()) {
            uint8_t v = (uint8_t)std::clamp(state.shutterValue, 0, 255);
            pixels[chan - 1] = xlColor(v, v, v);
        }
    }

    auto* adv = dynamic_cast<const DmxMovingHeadAdv*>(fixture);
    if (adv != nullptr) {
        auto const& features = adv->GetFeatures();
        for (auto const& fv : state.featureValues) {
            if (fv.featureIdx >= features.size()) {
                continue;
            }
            auto const& channels = features[fv.featureIdx]->GetChannels();
            if (fv.channelIdx >= channels.size()) {
                continue;
            }
            MhChannel* channel = channels[fv.channelIdx].get();
            int coarse = channel->GetChannelCoarse();
            int fine = channel->GetChannelFine();
            if (coarse > 0 && coarse <= (int)pixels.size()) {
                pixels[coarse - 1] = xlColor(fv.rawValue, fv.rawValue, fv.rawValue);
            }
            if (fine > 0 && fine <= (int)pixels.size()) {
                pixels[fine - 1] = xlColor(0, 0, 0);
            }
        }
    }

    // Model-authored fixed-channel overrides (e.g. a "16-bit mode enable"
    // channel that must always sit at a particular value) apply on top of
    // everything above, same as the real render pipeline.
    fixture->EnableFixedChannels(pixels);

    std::vector<uint8_t> bytes(pixels.size());
    for (size_t i = 0; i < pixels.size(); ++i) {
        bytes[i] = pixels[i].red;
    }

    if (adv != nullptr) {
        adv->ApplyPositionZones(bytes.data(), 0);
    }

    return bytes;
}

void MovingHeadTestEngine::Frame(OutputManager* outputManager, const DmxMovingHeadComm* fixture, const MHTestState& state)
{
    if (outputManager == nullptr || fixture == nullptr) {
        return;
    }

    std::vector<uint8_t> bytes = BuildFrameBytes(fixture, state);
    if (bytes.empty()) {
        return;
    }

    uint32_t firstChannel = fixture->GetFirstChannel();
    outputManager->SetManyChannels((int32_t)firstChannel, bytes.data(), bytes.size());

    _status = fmt::format("{} : channels {}-{}", fixture->GetName(), firstChannel + 1, firstChannel + bytes.size());
}

void MovingHeadTestEngine::ApplyToPreview(DmxMovingHeadComm* fixture, const MHTestState& state) const
{
    if (fixture == nullptr) {
        return;
    }

    std::vector<uint8_t> bytes = BuildFrameBytes(fixture, state);
    for (size_t i = 0; i < bytes.size(); ++i) {
        uint8_t v = bytes[i];
        fixture->SetNodeColor(i, xlColor(v, v, v));
    }
}

} // namespace xltest
