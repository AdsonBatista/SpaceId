import Cocoa
import Foundation

class SpaceIdentifier {
    
    let conn = _CGSDefaultConnection()
    let defaults = UserDefaults.standard
    
    typealias ScreenNumber = String
    typealias ScreenUUID = String
    
    func getSpaceInfo() -> SpaceInfo {
        
        guard let monitors = CGSCopyManagedDisplaySpaces(conn) as? [[String : Any]],
              let mainDisplay = NSScreen.main(),
              let screenNumber = mainDisplay.deviceDescription["NSScreenNumber"] as? UInt32
        else { return SpaceInfo(keyboardFocusSpace: nil, spaces: []) }
        
        //print(monitors)
        let cfuuid = CGDisplayCreateUUIDFromDisplayID(screenNumber).takeRetainedValue()
        let screenUUID = CFUUIDCreateString(kCFAllocatorDefault, cfuuid) as String
        print(screenUUID)
        let activeSpaces = parseSpaces(monitors: monitors)

        print(parseSpaces(monitors: monitors))
        return SpaceInfo(keyboardFocusSpace: activeSpaces[screenUUID], spaces: activeSpaces.map{ $0.value })
    }
    
    /* returns a mapping of screen uuids and their active space */
    private func parseSpaces(monitors: [[String : Any]]) -> [ScreenUUID : Space] {
        var ret: [ScreenUUID : Space] = [:]
        var counter = 1
        for m in monitors {
            guard let current = m["Current Space"] as? [String : Any],
                  let spaces = m["Spaces"] as? [[String : Any]],
                  let displayIdentifier = m["Display Identifier"] as? String
            else { continue }
            guard let id64 = current["id64"] as? Int,
                  let uuid = current["uuid"] as? String,
                  let type = current["type"] as? Int,
                  let managedSpaceId = current["ManagedSpaceID"] as? Int
            else { continue }
            
            let filterFullscreen = spaces.filter{ $0["TileLayoutManager"] as? [String : Any] == nil}
            let target = filterFullscreen.enumerated().first(where: { $1["uuid"] as? String == uuid})
            let number = target == nil ? nil : target!.offset + counter
            
            ret[displayIdentifier] = Space(id64: id64, uuid: uuid, type: type, managedSpaceId: managedSpaceId, number: number)
            counter += filterFullscreen.count
        }
        return ret
    }
}

