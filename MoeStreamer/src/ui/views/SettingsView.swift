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

	@Binding var musicCon: ServiceController



	init(musicCon: Binding<ServiceController>)
	{
		self._musicCon = musicCon
	}

	var body: some View {
		ZStack() {
			VStack(spacing: 16) {
				PrimarySettingsView()

				ListenMoeSettingsView(con: self.$musicCon)
			}
		}
		.frame(width: 280)
		.padding(.all, 12)
	}
}


private struct PrimarySettingsView : View
{
	@ObservedObject var shouldAutoRefresh = SavedSettingModel<Bool>(.shouldAutoRefresh())
	@ObservedObject var shouldAutoLogin   = SavedSettingModel<Bool>(.shouldAutoLogin())
	@ObservedObject var shouldNotifySong  = SavedSettingModel<Bool>(.shouldNotifySongChange(), didset: {
		if $0 { Notifier.create() }
	})

	var body: some View {
		VStack(alignment: .leading, spacing: 3) {

			HStack() {
				Toggle(isOn: self.$shouldAutoLogin.value) {
					Text("automatically login")
						.padding(.leading, 2)
						.toolTip("login to services automatically")
				}
			}

			HStack() {
				Toggle(isOn: self.$shouldNotifySong.value) {
					Text("notify on song change")
						.padding(.leading, 2)
						.toolTip("send a notification when the song changes")
				}
			}

			HStack() {
				Toggle(isOn: self.$shouldAutoRefresh.value) {
					Text("automatically refresh metadata")
						.padding(.leading, 2)
						.toolTip("force a metadata refresh every time the app is opened")
				}
			}

		}.frame(width: 250)
	}
}



private struct ListenMoeSettingsView : View
{
	@ObservedObject
	var moeUsername = SavedSettingModel<String>(.listenMoeUsername(), disableLogging: true)

	@ObservedObject
	var moePassword = SavedSettingModel<String>(.listenMoePassword(), disableLogging: true,
												getter: Settings.getKeychain,
												setter: Settings.setKeychain)

	@State var userField: NSTextField! = nil
	@State var passField: NSSecureTextField! = nil

	@Binding var musicCon: ServiceController

	// this is separate from the one on the main window.
	@ObservedObject var wrapper = ViewWrapper()

	init(con: Binding<ServiceController>)
	{
		self._musicCon = con
	}

	var body: some View {
		VStack(spacing: 0) {
			Text("listen.moe credentials")
			Divider().frame(width: 200).padding(.bottom, 8).padding(.top, 1)

			VStack(spacing: 3) {
				HStack() {
					Text("username").frame(width: 70)
					BetterTextField<NSTextField>(placeholder: "", text: self.$moeUsername.value, field: self.$userField)
				}

				HStack() {
					Text("password").frame(width: 70)
					BetterTextField<NSSecureTextField>(
						placeholder: "", text: self.$moePassword.value, field: self.$passField,
						onEnter: { (_, field: NSSecureTextField) in
							DispatchQueue.main.async {
								field.window?.makeFirstResponder(field.window)
							}

							self.musicCon.sessionLogin(activityView: self.wrapper, force: true)
					})
				}

				HStack(spacing: 2) {

					Spacer()

					if !self.wrapper.status.isEmpty
					{
						Text(self.wrapper.status)
							.multilineTextAlignment(.leading)
							.font(.system(size: 10))
							.lineLimit(2)
							.transition(.opacity)
							.fixedSize(horizontal: false, vertical: true)
							.padding(.trailing, 4)
					}


					if self.wrapper.spinning > 0
					{
						ActivityIndicator(size: .small)
							.frame(width: 24, height: 24)
					}

					Button(action: {
						DispatchQueue.main.async {
							// they share the same window, so we only need to fix the firstResponder once.
							self.userField?.window?.makeFirstResponder(self.userField?.window)
						}

						self.musicCon.sessionLogin(activityView: self.wrapper, force: true)
					}) {
						Text("login")
					}
					.padding(.vertical, 12)
				}
			}
		}
	}
}
