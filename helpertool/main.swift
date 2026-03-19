import Foundation

@objc protocol PrivilegedHelperToolProtocol: NSObjectProtocol {
	func applyOwnershipAndPermissions(_ path: String, uid: NSNumber, gid: NSNumber, mode: NSNumber, recursive: Bool, withReply reply: @escaping (Bool, String?) -> Void)
}

final class PrivilegedHelperTool: NSObject, NSXPCListenerDelegate, PrivilegedHelperToolProtocol {
	private let listener = NSXPCListener(machServiceName: "com.doumiao.Synchmod.helpertool")

	override init() {
		super.init()
		listener.delegate = self
	}

	func run() {
		listener.resume()
		RunLoop.current.run()
	}

	func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
		newConnection.exportedInterface = NSXPCInterface(with: PrivilegedHelperToolProtocol.self)
		newConnection.exportedObject = self
		newConnection.resume()
		return true
	}

	func applyOwnershipAndPermissions(_ path: String, uid: NSNumber, gid: NSNumber, mode: NSNumber, recursive: Bool, withReply reply: @escaping (Bool, String?) -> Void) {
		let fileManager = FileManager.default
		guard fileManager.fileExists(atPath: path) else {
			reply(false, "Path does not exist: \(path)")
			return
		}

		let modeString = String(format: "%o", mode.uint16Value)

		if recursive {
			let chownTask = Process()
			chownTask.executableURL = URL(fileURLWithPath: "/usr/sbin/chown")
			chownTask.arguments = ["-R", "\(uid.intValue):\(gid.intValue)", path]

			do {
				try chownTask.run()
				chownTask.waitUntilExit()
			} catch {
				reply(false, "Failed to run chown: \(error)")
				return
			}

			guard chownTask.terminationStatus == 0 else {
				reply(false, "chown failed with status \(chownTask.terminationStatus)")
				return
			}

			let chmodTask = Process()
			chmodTask.executableURL = URL(fileURLWithPath: "/bin/chmod")
			chmodTask.arguments = ["-R", modeString, path]

			do {
				try chmodTask.run()
				chmodTask.waitUntilExit()
			} catch {
				reply(false, "Failed to run chmod: \(error)")
				return
			}

			guard chmodTask.terminationStatus == 0 else {
				reply(false, "chmod failed with status \(chmodTask.terminationStatus)")
				return
			}
		} else {
			let chownStatus = chown(path, uid_t(uid.uint32Value), gid_t(gid.uint32Value))
			guard chownStatus == 0 else {
				reply(false, String(cString: strerror(errno)))
				return
			}

			let chmodStatus = chmod(path, mode_t(mode.uint16Value))
			guard chmodStatus == 0 else {
				reply(false, String(cString: strerror(errno)))
				return
			}
		}

		reply(true, nil)
	}
}

PrivilegedHelperTool().run()
