import AppKit

let args = CommandLine.arguments
guard args.count == 3 else {
    print("Usage: set_icon <app_path> <icns_path>")
    exit(1)
}

let appPath = args[1]
let icnsPath = args[2]

guard let icon = NSImage(contentsOfFile: icnsPath) else {
    print("Failed to load icon from \(icnsPath)")
    exit(1)
}

NSWorkspace.shared.setIcon(icon, forFile: appPath, options: [])
print("Icon set: \(appPath)")
