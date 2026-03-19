import ServiceManagement
import Security

func installHelper() throws {

	var authRef: AuthorizationRef?

	let createStatus = AuthorizationCreate(
		nil,
		nil,
		[],
		&authRef
	)

	guard createStatus == errAuthorizationSuccess, let authRef else {
		throw NSError(domain: NSOSStatusErrorDomain, code: Int(createStatus))
	}

	let copyStatus: OSStatus = kSMRightBlessPrivilegedHelper.withCString { blessRightName in
		var authItem = AuthorizationItem(
			name: blessRightName,
			valueLength: 0,
			value: nil,
			flags: 0
		)

		return withUnsafeMutablePointer(to: &authItem) { authItemPtr in
			var authRights = AuthorizationRights(count: 1, items: authItemPtr)

			return AuthorizationCopyRights(
				authRef,
				&authRights,
				nil,
				[.interactionAllowed, .extendRights, .preAuthorize],
				nil
			)
		}
	}

	guard copyStatus == errAuthorizationSuccess else {
		throw NSError(domain: NSOSStatusErrorDomain, code: Int(copyStatus))
	}

	var error: Unmanaged<CFError>?

	let success = SMJobBless(
		kSMDomainSystemLaunchd,
		"com.doumiao.Synchmod.helpertool" as CFString,
		authRef,
		&error
	)

	if !success {
		if let cfError = error?.takeRetainedValue() {
			let nsError = cfError as Error as NSError
			print("SMJobBless failed domain=\(nsError.domain) code=\(nsError.code) userInfo=\(nsError.userInfo)")
			throw nsError
		}

		throw NSError(
			domain: NSOSStatusErrorDomain,
			code: Int(errAuthorizationDenied),
			userInfo: [NSLocalizedDescriptionKey: "SMJobBless failed without CFError"]
		)
	}
}
//

