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

#include "Color.h"

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

class OutputManager;
class DmxMovingHeadComm;

namespace xltest {

// One dynamically-discovered MhFeature/MhChannel value the UI is driving on
// an advanced moving head. featureIdx/channelIdx index into
// DmxMovingHeadAdv::GetFeatures() and MhFeature::GetChannels(). rawValue is
// the coarse byte (0-255); 16-bit MhChannels always get a fine byte of 0 in
// v1 (no UI exposes sub-256 precision on these yet).
struct MHTestFeatureValue {
    size_t featureIdx { 0 };
    size_t channelIdx { 0 };
    uint8_t rawValue { 0 };
};

// One open Moving Head test session's worth of "what should this fixture be
// doing right now." Rebuilt from widget state every frame by the caller -
// cheap, a handful of scalars plus a small vector - mirroring how
// PixelTestDialog::BuildTestParameters() rebuilds xltest::TestParameters.
struct MHTestState {
    float panDegrees { 0.0f };
    float tiltDegrees { 0.0f };

    // The desired beam color, for any color ability type. DmxColorAbility::
    // SetColorPixels() already resolves an arbitrary xlColor against
    // whichever concrete ability the fixture has - RGB(W)/CMY(W) decompose
    // it channel-by-channel, and a color wheel does its own nearest-hue
    // match against that fixture's own wheel slots - so one field here
    // covers every color ability type and, critically, resolves correctly
    // per-fixture when driving a mixed selection of different wheel
    // fixtures (each finds its own nearest slot rather than sharing a
    // pre-resolved index into someone else's slot list).
    xlColor rgbColor { 255, 255, 255 };

    int dimmer { 255 };          // 0-255, only written if HasDimmerAbility()

    // The raw byte (0-255) written to the shutter channel, only if
    // HasShutterAbility(). Not just an open/closed bool - some fixtures pack
    // strobe rate or other functions onto the same channel, so the caller's
    // UI is expected to offer a full slider with an open/closed shortcut
    // layered on top, rather than this engine assuming binary semantics.
    int shutterValue { 255 };

    // Advanced fixtures only: current value of every MhFeature/MhChannel the
    // UI is showing a control for. Sparse - channels not present here stay 0.
    std::vector<MHTestFeatureValue> featureValues;
};

// Drives one Moving Head fixture test session: turns an MHTestState into DMX
// bytes and pushes them out over OutputManager. Wx-free so it could
// eventually be shared with the iPad, mirroring why xltest::TestPatternEngine
// (the engine behind the other four Tools > Test families) lives here rather
// than in the dialog - unlike that engine, this one drives one fixture's
// full set of abilities continuously rather than a chase/twinkle pattern
// across a channel list.
class MovingHeadTestEngine
{
public:
    MovingHeadTestEngine() = default;

    // Idle/home state to populate the UI with when a fixture is first
    // selected. Not read back from live output - nothing guarantees the
    // fixture is even receiving data - so this is always the fixture's
    // designed home position (angle 0,0, which DmxMotor::ConvertPostoCmd
    // already resolves correctly per-motor, honoring orient_home/reverse/
    // upside_down) plus a deliberate "beam visible" default (full dimmer,
    // open shutter, white) so the fixture is immediately useful for aiming.
    static MHTestState HomeState(const DmxMovingHeadComm* fixture);

    // Emits one frame for `fixture` at `state`. Caller brackets this with
    // OutputManager::StartFrame/EndFrame as usual.
    void Frame(OutputManager* outputManager, const DmxMovingHeadComm* fixture, const MHTestState& state);

    // Writes state's per-channel bytes directly into fixture's own node
    // colors (Model::SetNodeColor) instead of sending them out over DMX, so
    // a ModelPreview showing this model reflects the test panel live even
    // when output-to-lights is off or no controller is attached. Node index
    // i is always relative channel i+1 for DmxModel-derived models
    // (DmxModel::InitModel creates exactly one node per channel), the same
    // convention Frame()'s byte buffer uses.
    void ApplyToPreview(DmxMovingHeadComm* fixture, const MHTestState& state) const;

    // Human-readable one-liner for the status bar.
    const std::string& GetStatus() const { return _status; }

    // Splits a motor's internal command value (DmxMotor::ConvertPostoCmd's
    // 0-65535 return, not itself a DMX value) into the exact two DMX bytes
    // (each 0-255) Frame() sends over the wire for that motor - coarseByte to
    // its coarse channel always, fineByte to its fine channel only if it has
    // one. This is the single source of truth for "what byte(s) does this
    // angle actually produce," so a UI showing a raw-DMX readout can't drift
    // from what Frame() really transmits.
    static void SplitMotorCommand(int cmd, uint8_t& coarseByte, uint8_t& fineByte);

    // Computes the exact per-channel byte array Frame()/ApplyToPreview()
    // send for `state`, without sending it anywhere - the single source of
    // truth for a UI wanting a live raw-DMX readout that can't drift from
    // what real output actually transmits.
    std::vector<uint8_t> BuildFrameBytes(const DmxMovingHeadComm* fixture, const MHTestState& state) const;

private:
    std::string _status;
};

} // namespace xltest
