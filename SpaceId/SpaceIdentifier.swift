//
//  SpaceIdentifier.swift
//  SpaceId
//
//  Created by Dennis Kao on 3/2/17.
//  Copyright © 2017 Dennis Kao. All rights reserved.
//

import Cocoa
import Foundation
import Swiftz

class SpaceIdentifier {
    
    func getActiveSpaceNumber() -> Int {
        guard let defaults = parseSpacesPlist(),
              let spaceDisplayConfiguration = defaults.dictionary(forKey: "SpacesDisplayConfiguration")
        else {
            print("fail to load SpaceDisplayConfiguration")
            return 0
        }
        let spaceProperties: [SpaceProperty] = parseSpaceProperties(dict: spaceDisplayConfiguration)
        let spaces: [Space] = parseSpaces(dict: spaceDisplayConfiguration)
        let activeSpaceUUIDs = getActiveSpaceUUIDs(spaceIdByWindowNumber: getSpaceIdByWindowId(spaceProperties: spaceProperties))
        guard let activeSpace = spaces.enumerated().first(where: { (offset: Int, s: Space) -> Bool in
            let isMain = isActiveScreenMain()
            return activeSpaceUUIDs.contains(s.uuid) &&
                   ((s.displayIdentifier == "Main" && isMain) || (s.displayIdentifier != "Main" && !isMain))
        })
        else { return 0 }
        return activeSpace.offset + 1
    }

    private func parseSpacesPlist() -> UserDefaults? {
        guard let defaults = UserDefaults(suiteName: "com.apple.spaces") else {
            print("com.apple.spaces not found")
            return nil
        }
        defaults.synchronize()
        return defaults
    }
    
    private func parseSpaceProperties(dict: [String : Any]) -> [SpaceProperty] {
        guard let spaceDicts = dict["Space Properties"] as? [[String : Any]] else {
            print("fail to load space properties")
            return []
        }
        var spaceProperties: [SpaceProperty] = []
        for s in spaceDicts {
            if let name = s["name"] as? String, let windows = s["windows"] as? [Int] {
                spaceProperties.append(SpaceProperty(name: name, windows: windows))
            } else { print (" fail to parse space properties") }
        }
        return spaceProperties
    }
    
    /* return a list of all spaces in order from desktop 1 to N */
    private func parseSpaces(dict: [String: Any]) -> [Space] {
        guard let managementData = dict["Management Data"] as? [String : Any],
              let monitors = managementData["Monitors"] as? [[String : Any]]
        else {
            print("monitors not found")
            return []
        }
        var ret: [Space] = []
        for m in monitors {
            guard let spaces = m["Spaces"] as? [[String : Any]],
                  let displayIdentifier = m["Display Identifier"] as? String
            else { continue }
            for space in spaces {
                guard let id64 = space["id64"] as? Int,
                      let uuid = space["uuid"] as? String,
                      let type = space["type"] as? Int,
                      let managedSpaceId = space["ManagedSpaceID"] as? Int
                else {
                    print("fail to parse spaces")
                    continue
                }
                ret.append(Space(id64: id64, uuid: uuid, type: type, managedSpaceId: managedSpaceId, displayIdentifier: displayIdentifier))
            }
        }
        return ret
    }
    
    /* [WindowId : [SpaceUUID]]
     */
    private func getSpaceIdByWindowId(spaceProperties: [SpaceProperty]) -> Dictionary<Int, String> {
        var spaceIdByWindowId = Dictionary<Int, [String]>()
        for property in spaceProperties {
            for window in property.windows {
                spaceIdByWindowId[window] = (spaceIdByWindowId[window] ?? []) + [property.name]
            }
        }
        return spaceIdByWindowId.filter{$0.count == 1}.map{$0[0]}
    }
    
    private func getActiveSpaceUUIDs(spaceIdByWindowNumber: Dictionary<Int, String>) -> Set<String> {
        guard let windowDescriptions =
            CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String : Any]]
        else {
            print("fail to get window descriptions")
            return []
        }
        var activeSpaceUUIDs: Set<String> = []
        for d in windowDescriptions {
            guard let windowNumber = d[kCGWindowNumber as String] as? Int,
                  let spaceIdentifier = spaceIdByWindowNumber[windowNumber]
            else { continue }
            activeSpaceUUIDs.insert(spaceIdentifier)
        }
        return activeSpaceUUIDs
    }
    
    private func isActiveScreenMain() -> Bool {
        guard let keyboardFocusScreen = NSScreen.main(),
              let screens = NSScreen.screens(),
              screens.count >= 1
        else {
            return true // assume main screen if no info
        }
        return keyboardFocusScreen == screens[0]
    }
}
