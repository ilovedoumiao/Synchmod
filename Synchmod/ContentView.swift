import AppKit
import CryptoKit
import Darwin
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {

	@State private var selectedURL: URL? = nil

	@State private var recursive = false
	//@State private var progress: Double = 0
	//@State private var isRunning = false

	@State private var ownerName: String = ""
	@State private var groupName: String = ""
	@State private var everyName: String = "NA"

	@State private var availableUsers: [String] = []
	@State private var availableGroups: [String] = []

	@State private var numericPerms: String = ""

	@State private var owner = PermissionSet(
		read: false,
		write: false,
		exec: false
	)
	@State private var group = PermissionSet(
		read: false,
		write: false,
		exec: false
	)
	@State private var other = PermissionSet(
		read: false,
		write: false,
		exec: false
	)

	@State private var showDropZoneError = false
	private let helperLabel = "com.doumiao.Synchmod.helpertool"

	var body: some View {

		VStack(alignment: .leading, spacing: 24) {

			DropZone(
				selectedURL: $selectedURL,
				onFileAdded: { url in
					fetchPerms(from: url)
				},
				onClick: {
					openPanel()
				},
				showHighlight: $showDropZoneError
			)

			Divider()

			// user + group + everyone
			HStack(spacing: 40) {

				VStack(alignment: .leading) {
					Text("Owner:")
						.padding(.leading, 7)
					Picker("", selection: $ownerName) {
						ForEach(availableUsers, id: \.self) { Text($0) }
					}
					.frame(width: 120)
				}
				.disabled(selectedURL == nil)

				VStack(alignment: .leading) {
					Text("Group:")
						.padding(.leading, 7)
					Picker("", selection: $groupName) {
						ForEach(availableGroups, id: \.self) { Text($0) }
					}
					.frame(width: 120)
				}
				.disabled(selectedURL == nil)

				VStack(alignment: .leading) {
					Text("Everyone:")
						.padding(.leading, 7)
					Picker("", selection: $everyName) {
						Text("Not applicable")
							.tag("NA")
					}
					.disabled(true)
					.frame(width: 120)
				}
			}

			// perms matrix
			HStack(spacing: 40) {

				PermissionColumn(title: "", perms: $owner) {
					updateNumeric()
				}

				PermissionColumn(title: "", perms: $group) {
					updateNumeric()
				}

				PermissionColumn(title: "", perms: $other) {
					updateNumeric()
				}
			}
			.disabled(selectedURL == nil)

			// num notate
			HStack {

				HStack {
					Text("Numeric Notation:")
					TextField("", text: $numericPerms)
						.font(.system(.body, design: .monospaced))
						.frame(width: 48)
						.textFieldStyle(.roundedBorder)
						.onChange(of: numericPerms) {
							filterNumeric()
							applyNumericPermissions(numericPerms)
						}
				}

				Spacer()

				HStack {
					Text("Presets:")

					Button("644") { setPreset(0o644) }
						.font(.system(.body, design: .monospaced))
					Button("700") { setPreset(0o700) }
						.font(.system(.body, design: .monospaced))
					Button("755") { setPreset(0o755) }
						.font(.system(.body, design: .monospaced))
					Button("777") { setPreset(0o777) }
						.font(.system(.body, design: .monospaced))
				}
			}
			.disabled(selectedURL == nil)

			// recursive
			HStack {

				Toggle("Recursive (folders)", isOn: $recursive)
					.toggleStyle(.switch)
					.controlSize(.small)

				Spacer()

				Text(symbolicPermissions(currentMode()))
					.font(.system(.body, design: .monospaced))
					.opacity(0.4)
					.padding(8)
					.overlay(
						RoundedRectangle(cornerRadius: 8)
							.stroke(Color.gray.opacity(0.2))
					)
			}
			.disabled(selectedURL == nil)

			// btns
			HStack {
				Button(action: {
					selectedURL = nil
					ownerName = ""
					groupName = ""
					numericPerms = ""
				}) {
					Text("Reset")
						.frame(minWidth: 40)
				}
				.controlSize(.large)

				Spacer()

				Button(action: {
					if selectedURL == nil {
						showDropZoneError = true
					} else {
						var helperReady = true
						do {
							try ensureHelperIsCurrent()
						} catch {
							helperReady = false
							print("Helper install failed:", error)
						}
						if helperReady {
							applyPermissions()
						}
					}
				}) {
					Text("Apply")
						.frame(minWidth: 128)
				}
				.buttonStyle(.borderedProminent)
				.controlSize(.large)
			}
			/*
			 if isRunning {
			 ProgressView(value: progress)
			 }
			 */
		}
		.padding()
		.onAppear {
			
			availableUsers = dsclList("/Users")
			availableGroups = dsclList("/Groups")
			
			//ownerName = NSUserName()
			//groupName = currentGroupName()
			ownerName = ""
			groupName = ""
		}
	}

	func currentMode() -> Int {

		var m = 0

		if owner.read { m |= 0o400 }
		if owner.write { m |= 0o200 }
		if owner.exec { m |= 0o100 }

		if group.read { m |= 0o040 }
		if group.write { m |= 0o020 }
		if group.exec { m |= 0o010 }

		if other.read { m |= 0o004 }
		if other.write { m |= 0o002 }
		if other.exec { m |= 0o001 }

		return m
	}

	func setPermissions(from mode: Int) {

		owner.read = (mode & 0o400) != 0
		owner.write = (mode & 0o200) != 0
		owner.exec = (mode & 0o100) != 0

		group.read = (mode & 0o040) != 0
		group.write = (mode & 0o020) != 0
		group.exec = (mode & 0o010) != 0

		other.read = (mode & 0o004) != 0
		other.write = (mode & 0o002) != 0
		other.exec = (mode & 0o001) != 0
	}

	func updateNumeric() {
		numericPerms = String(format: "%o", currentMode())
	}

	func applyNumericPermissions(_ str: String) {

		guard let value = Int(str, radix: 8) else { return }

		setPermissions(from: value)
	}

	func setPreset(_ value: Int) {

		setPermissions(from: value)
		numericPerms = String(format: "%o", value)
	}

	func filterNumeric() {

		let filtered = String(
			numericPerms
				.prefix(3)
				.filter { "01234567".contains($0) }
		)

		if filtered != numericPerms {
			numericPerms = filtered
		}
	}

	func openPanel() {

		let panel = NSOpenPanel()
		panel.canChooseFiles = true
		panel.canChooseDirectories = true
		panel.allowsMultipleSelection = true

		if panel.runModal() == .OK {

			if let first = panel.urls.first {
				selectedURL = first
				fetchPerms(from: first)
			}
		}
	}

	func fetchPerms(from url: URL) {

		guard
			let attrs = try? FileManager.default.attributesOfItem(
				atPath: url.path
			),
			let perms = attrs[.posixPermissions] as? NSNumber
		else { return }

		let mode = perms.intValue

		setPermissions(from: mode)
		numericPerms = String(format: "%o", mode)

		if let owner = attrs[.ownerAccountName] as? String {
			ownerName = owner
		}

		if let group = attrs[.groupOwnerAccountName] as? String {
			groupName = group
		}
	}

	func applyPermissions() {

		guard let url = selectedURL else { return }

		let mode = currentMode()
		let uid = uidFromName(ownerName)
		let gid = gidFromName(groupName)

		let basePath = url.path

		DispatchQueue.global(qos: .userInitiated).async {
			runPrivilegedApply(path: basePath, uid: uid, gid: gid, mode: mode_t(mode))
		}
	}

	func ensureHelperIsCurrent() throws {
		if helperNeedsInstallOrUpdate() {
			try installHelper()
		}
	}

	func helperNeedsInstallOrUpdate() -> Bool {
		let installedURL = URL(fileURLWithPath: "/Library/PrivilegedHelperTools/\(helperLabel)")
		guard FileManager.default.fileExists(atPath: installedURL.path) else {
			return true
		}

		let bundledURL = Bundle.main.bundleURL
			.appendingPathComponent("Contents/Library/LaunchServices/\(helperLabel)")

		guard
			let bundledDigest = helperDigest(at: bundledURL),
			let installedDigest = helperDigest(at: installedURL)
		else {
			return true
		}

		return bundledDigest != installedDigest
	}

	func helperDigest(at url: URL) -> String? {
		guard let data = try? Data(contentsOf: url) else {
			return nil
		}

		let digest = SHA256.hash(data: data)
		return digest.map { String(format: "%02x", $0) }.joined()
	}

	func runPrivilegedApply(path: String, uid: uid_t, gid: gid_t, mode: mode_t) {
		let connection = NSXPCConnection(
			machServiceName: helperLabel,
			options: .privileged
		)

		connection.remoteObjectInterface = NSXPCInterface(
			with: PrivilegedHelperToolProtocol.self
		)

		connection.resume()

		let semaphore = DispatchSemaphore(value: 0)
		var didSucceed = false

		let proxy = connection.remoteObjectProxyWithErrorHandler { error in
			print("Helper XPC error:", error)
			semaphore.signal()
		} as? PrivilegedHelperToolProtocol

		guard let proxy else {
			print("Helper proxy unavailable")
			connection.invalidate()
			return
		}

		proxy.applyOwnershipAndPermissions(
			path,
			uid: NSNumber(value: uid),
			gid: NSNumber(value: gid),
			mode: NSNumber(value: UInt16(mode)),
			recursive: recursive
		) { success, message in
			didSucceed = success
			if let message {
				print("Helper reply:", message)
			}
			semaphore.signal()
		}

		_ = semaphore.wait(timeout: .now() + 10)
		connection.invalidate()

		if !didSucceed {
			print("Helper apply failed")
		}
	}
}

@objc protocol PrivilegedHelperToolProtocol: NSObjectProtocol {
	func applyOwnershipAndPermissions(_ path: String, uid: NSNumber, gid: NSNumber, mode: NSNumber, recursive: Bool, withReply reply: @escaping (Bool, String?) -> Void)
}

struct PermissionSet {

	var read: Bool
	var write: Bool
	var exec: Bool
}

struct PermissionColumn: View {

	let title: String
	@Binding var perms: PermissionSet
	var onChange: () -> Void

	var body: some View {

		VStack {

			HStack(spacing: 42) {
				Text("r")
				Text("w")
				Text("x")
					.padding(.trailing, -7)
			}
			.font(.system(.body, design: .monospaced))

			HStack(spacing: 32) {

				Toggle("", isOn: $perms.read)
					.padding(.leading, 11)
					.toggleStyle(.checkbox)
					.onChange(of: perms.read) { onChange() }

				Toggle("", isOn: $perms.write)
					.toggleStyle(.checkbox)
					.onChange(of: perms.write) { onChange() }

				Toggle("", isOn: $perms.exec)
					.toggleStyle(.checkbox)
					.onChange(of: perms.exec) { onChange() }
			}
		}
		.frame(width: 120)
	}
}

struct DropZone: View {

	@Binding var selectedURL: URL?
	var onFileAdded: (URL) -> Void
	var onClick: () -> Void

	@State private var isTargeted = false

	@State private var dashPhase: CGFloat = 0
	@Binding var showHighlight: Bool

	var body: some View {

		RoundedRectangle(cornerRadius: 8)
			.stroke(
				isTargeted ? Color.accentColor : Color.gray,
				style: StrokeStyle(
					lineWidth: 3,
					dash: [9, 6.5],
					dashPhase: dashPhase
				)
			)
			//.clipShape(RoundedRectangle(cornerRadius: 8))
			.opacity(showHighlight ? 1 : 0.3)
			.background(
				RoundedRectangle(cornerRadius: 8)
					.opacity(showHighlight ? 0.1 : 0)
			)
			.animation(.easeInOut(duration: 0.2), value: showHighlight)
			.frame(height: 96)
			.overlay(
				Group {

					if let url = selectedURL {

						VStack(spacing: 6) {

							Text(url.lastPathComponent)
								.font(.headline)
								.lineLimit(1)
								.frame(width: 400)

							Text(url.path)
								.font(.system(size: 11, design: .monospaced))
								.lineLimit(1)
								.truncationMode(.middle)
								.opacity(0.6)
								.frame(width: 400)
						}
					} else {

						VStack(spacing: 8) {

							Image(systemName: "tray.and.arrow.down")
								.font(.system(size: 28))
								.opacity(showHighlight ? 1 : 0.3)
								.animation(
									.easeInOut(duration: 0.2),
									value: showHighlight
								)

							Text("Drop file/folder here or click to select.")
								.font(.headline)
								.opacity(showHighlight ? 1 : 0.3)
								.animation(
									.easeInOut(duration: 0.2),
									value: showHighlight
								)
						}
					}
				}
			)

			.contentShape(Rectangle())

			.onTapGesture { onClick() }

			.onHover { hovering in
				if hovering {
					NSCursor.pointingHand.push()
				} else {
					NSCursor.pop()
				}
			}

			.onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
				let group = DispatchGroup()
				var droppedURLs: [URL] = []

				for provider in providers {
					if provider.canLoadObject(ofClass: URL.self) {
						group.enter()
						_ = provider.loadObject(ofClass: URL.self) { url, _ in
							if let url = url {
								droppedURLs.append(url)
							}
							group.leave()
						}
					}
				}

				group.notify(queue: .main) {
					if let first = droppedURLs.first {
						selectedURL = first
						onFileAdded(first)
					}
				}

				return true
			}

			.onChange(of: showHighlight) { oldValue, newValue in
				if newValue {
					withAnimation(
						.linear(duration: 0.2).repeatForever(
							autoreverses: false
						)
					) {
						dashPhase = -15
					}

					DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
						withAnimation(.easeOut(duration: 0.2)) {
							dashPhase = 0
							showHighlight = false
						}
					}
				} else {
					dashPhase = 0
				}
			}
	}
}

func dsclList(_ path: String) -> [String] {

	let task = Process()
	task.launchPath = "/usr/bin/dscl"
	task.arguments = [".", "-list", path]

	let pipe = Pipe()
	task.standardOutput = pipe

	try? task.run()

	let data = pipe.fileHandleForReading.readDataToEndOfFile()

	guard let output = String(data: data, encoding: .utf8) else { return [] }

	return output.split(separator: "\n").map(String.init)
}

func uidFromName(_ name: String) -> uid_t {

	if let pw = getpwnam(name) {
		return pw.pointee.pw_uid
	}

	return getuid()
}

func gidFromName(_ name: String) -> gid_t {

	if let gr = getgrnam(name) {
		return gr.pointee.gr_gid
	}

	return getgid()
}

func currentGroupName() -> String {

	let gid = getgid()

	if let group = getgrgid(gid) {
		return String(cString: group.pointee.gr_name)
	}

	return "staff"
}

func symbolicPermissions(_ value: Int) -> String {

	let chars = ["r", "w", "x"]
	var result = ""

	for i in stride(from: 6, through: 0, by: -3) {

		let part = (value >> i) & 7

		for j in 0..<3 {
			result += (part & (1 << (2 - j))) != 0 ? chars[j] : "-"
		}
	}

	return result
}
