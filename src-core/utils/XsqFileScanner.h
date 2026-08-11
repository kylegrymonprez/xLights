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

// Lightweight scanner that peeks at the first few KB of an .xsq / .xml
// file to detect whether it is an xLights sequence and to extract the
// media filename.  Does NOT parse the entire file — safe to call on
// arbitrarily large files.

#include <map>
#include <string>

struct XsqFileInfo {
    bool isSequence = false;   // true if <xsequence was found
    std::string mediaFile;     // content of <mediaFile>...</mediaFile>, empty if absent
    std::map<std::string, std::string> altTrackPaths;      // alt track shortname -> path
    std::map<std::string, std::string> controllerMediaMap; // controller name -> alt track shortname

    // Resolves the alt track path mapped to controllerName, or "" if there
    // is no mapping / the mapped shortname doesn't match a known track
    // (caller falls back to mediaFile in that case).
    std::string ResolveMediaForController(const std::string& controllerName) const;
};

// Read at most the first ~48 KB looking for <xsequence>, <mediaFile>,
// <altAudioTracks>, and <controllerMediaMap>. Returns immediately once
// everything is resolved or the buffer is exhausted.
XsqFileInfo ScanXsqFile(const std::string& filename);
