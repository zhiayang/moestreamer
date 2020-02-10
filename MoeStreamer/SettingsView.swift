// SettingsView.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import SwiftUI
import Foundation

struct SettingsView : View
{
	@Environment(\.colorScheme)
	var colourScheme: ColorScheme

	@State var moeUsername: String = Settings.get(key: "listenMoe_username", default: "")
	@State var moePassword: String = Settings.getKeychain(key: "listenMoe_password", default: "")

	@Binding var musicCon: ServiceController

	// this is separate from the one on the main window.
	@ObservedObject var wrapper = ViewWrapper()

	init(musicCon: Binding<ServiceController>)
	{
		self._musicCon = musicCon
	}

	var body: some View {
		ZStack() {

			VStack() {
				Text("listen.moe")
				Divider()

				VStack(spacing: 3) {
					HStack() {
						Text("username").frame(width: 70)
						TextField("", text: self.$moeUsername, onEditingChanged: { _ in
							Settings.set(key: "listenMoe_username", value: self.moeUsername)
						})
					}

					HStack() {
						Text("password").frame(width: 70)
						SecureField("", text: self.$moePassword, onCommit: {
							Settings.setKeychain(key: "listenMoe_password", value: self.moePassword)
						})
					}

					HStack(spacing: 2) {

						if !self.wrapper.status.isEmpty
						{
							Text(self.wrapper.status)
								.multilineTextAlignment(.leading)
								.font(.system(size: 10))
								.lineLimit(2)
								.transition(.opacity)
								.fixedSize(horizontal: false, vertical: true)
						}

						Spacer()

						if self.wrapper.spinning > 0
						{
							ActivityIndicator()
								.frame(width: 16, height: 16)
						}

						Button(action: {
							self.musicCon.sessionLogin(activityView: self.wrapper)
						}) {
							Text("login")
						}
						.padding(.vertical, 12)
					}
				}
			}
		}
		.frame(width: 240, height: 110)
		.padding(.all, 12)
		.padding(.top, 20)
	}
}
