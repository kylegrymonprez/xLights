/***************************************************************
 * This source files comes from the xLights project
 * https://www.xlights.org
 * https://github.com/xLightsSequencer/xLights
 * See the github commit history for a record of contributing
 * developers.
 * Copyright claimed based on commit dates recorded in Github
 * License: https://github.com/xLightsSequencer/xLights/blob/master/License.txt
 **************************************************************/

#include "XsqFileScanner.h"
#include "ExternalHooks.h"

#include <fstream>

// Decode the five XML predefined entities in a short string.
static std::string DecodeXmlEntities(const std::string& s) {
    std::string out;
    out.reserve(s.size());
    for (size_t i = 0; i < s.size(); ++i) {
        if (s[i] == '&') {
            if (s.compare(i, 4, "&lt;") == 0) { out += '<';  i += 3; }
            else if (s.compare(i, 4, "&gt;") == 0) { out += '>';  i += 3; }
            else if (s.compare(i, 5, "&amp;") == 0) { out += '&';  i += 4; }
            else if (s.compare(i, 6, "&apos;") == 0) { out += '\''; i += 5; }
            else if (s.compare(i, 6, "&quot;") == 0) { out += '"';  i += 5; }
            else { out += s[i]; }
        } else {
            out += s[i];
        }
    }
    return out;
}

// Extracts attrName="..." from a tag-open fragment (e.g. `<track shortname="Drums"`).
// Returns "" if the attribute isn't present.
static std::string ExtractAttribute(const std::string& tagOpen, const std::string& attrName) {
    std::string needle = attrName + "=\"";
    auto pos = tagOpen.find(needle);
    if (pos == std::string::npos) return "";
    pos += needle.size();
    auto end = tagOpen.find('"', pos);
    if (end == std::string::npos) return "";
    return DecodeXmlEntities(tagOpen.substr(pos, end - pos));
}

// Scans `buf` for repeated `<childTag attrName="...">text</childTag>` entries
// inside a `<containerTag>...</containerTag>` block, calling `cb(attrValue, text)`
// for each. No-op if the container tag isn't present.
template <typename Callback>
static void ScanTaggedEntries(const std::string& buf, const std::string& containerTag,
                               const std::string& childTag, const std::string& attrName, Callback cb) {
    auto containerStart = buf.find("<" + containerTag);
    if (containerStart == std::string::npos) return;
    auto containerEnd = buf.find("</" + containerTag + ">", containerStart);
    if (containerEnd == std::string::npos) containerEnd = buf.size();

    const std::string openPrefix = "<" + childTag;
    const std::string closeTag = "</" + childTag + ">";
    size_t pos = containerStart;
    while (true) {
        auto tagStart = buf.find(openPrefix, pos);
        if (tagStart == std::string::npos || tagStart >= containerEnd) break;
        auto tagOpenEnd = buf.find('>', tagStart);
        if (tagOpenEnd == std::string::npos || tagOpenEnd >= containerEnd) break;
        std::string attrValue = ExtractAttribute(buf.substr(tagStart, tagOpenEnd - tagStart), attrName);

        auto textStart = tagOpenEnd + 1;
        auto textEnd = buf.find(closeTag, textStart);
        if (textEnd == std::string::npos || textEnd > containerEnd) break;

        if (!attrValue.empty()) {
            cb(attrValue, DecodeXmlEntities(buf.substr(textStart, textEnd - textStart)));
        }
        pos = textEnd + closeTag.size();
    }
}

std::string XsqFileInfo::ResolveMediaForController(const std::string& controllerName) const {
    auto mapIt = controllerMediaMap.find(controllerName);
    if (mapIt == controllerMediaMap.end()) return "";
    auto trackIt = altTrackPaths.find(mapIt->second);
    if (trackIt == altTrackPaths.end()) return "";
    return trackIt->second;
}

XsqFileInfo ScanXsqFile(const std::string& filename) {
    XsqFileInfo info;

    // Read the first 48 KB — metadata is always near the top of xLights files.
    static constexpr size_t SCAN_SIZE = 48 * 1024;
    std::string buf(SCAN_SIZE, '\0');

    ObtainAccessToURL(filename);

    std::ifstream file(filename, std::ios::binary);
    if (!file) return info;

    file.read(&buf[0], SCAN_SIZE);
    buf.resize(static_cast<size_t>(file.gcount()));
    if (buf.empty()) return info;

    // Look for <xsequence (with possible attributes or just >)
    if (buf.find("<xsequence") != std::string::npos) {
        info.isSequence = true;
    }

    // Look for <mediaFile>...</mediaFile>
    const std::string openTag = "<mediaFile>";
    const std::string closeTag = "</mediaFile>";
    auto start = buf.find(openTag);
    if (start != std::string::npos) {
        start += openTag.size();
        auto end = buf.find(closeTag, start);
        if (end != std::string::npos) {
            info.mediaFile = DecodeXmlEntities(buf.substr(start, end - start));
        }
    }

    ScanTaggedEntries(buf, "altAudioTracks", "track", "shortname",
                      [&](const std::string& shortname, const std::string& path) {
                          info.altTrackPaths[shortname] = path;
                      });
    ScanTaggedEntries(buf, "controllerMediaMap", "entry", "controller",
                      [&](const std::string& controllerName, const std::string& shortname) {
                          info.controllerMediaMap[controllerName] = shortname;
                      });

    return info;
}
