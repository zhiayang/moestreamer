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
	@ObservedObject var shouldUseKeyboard = SavedSettingModel<Bool>(.shouldUseKeyboardShortcuts())
	@ObservedObject var shouldNotifySong  = SavedSettingModel<Bool>(.shouldNotifySongChange(), didset: {
		if $0 { Notifier.create() }
	})

	@ObservedObject var streamBufferMs    = SavedSettingModel<Int>(.streamBufferMs(), willset: {
		return (100 ... 10000).contains($0)
	})

	var body: some View {
		VStack(alignment: .leading, spacing: 3) {

			HStack() {
				Toggle(isOn: self.$shouldUseKeyboard.value) {
					Text("keyboard shortcuts")
						.padding(.leading, 2)
						.tooltip("spacebar to play/pause, m to mute/unmute")
				}
			}

			HStack() {
				Toggle(isOn: self.$shouldAutoLogin.value) {
					Text("automatically login")
						.padding(.leading, 2)
						.tooltip("login to services automatically")
				}
			}

			HStack() {
				Toggle(isOn: self.$shouldNotifySong.value) {
					Text("notify on song change")
						.padding(.leading, 2)
						.tooltip("send a notification when the song changes")
				}
			}

			HStack() {
				Toggle(isOn: self.$shouldAutoRefresh.value) {
					Text("automatically refresh metadata")
						.padding(.leading, 2)
						.tooltip("force a metadata refresh every time the app is opened")
				}
			}

			HStack() {
				Text("stream buffer (ms)")
					.padding(.leading, 2)
					.tooltip("how much audio to buffer (effectively stream delay)")

				Stepper(value: self.$streamBufferMs.value, in: 100 ... 10000, step: 100) {
					TextField("", value: self.$streamBufferMs.value, formatter: IntegerNumberFormatter())
						.frame(width: 48)
				}

			}.padding(.top, 4)

		}.frame(width: 280)
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

	// this is separate from the one on the main window.
	@ObservedObject var model: MainModel

	init(con: Binding<ServiceController>)
	{
		self.model = MainModel(controller: con.wrappedValue)
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

							self.model.controller().sessionLogin(activityView: self.model as ViewModel, force: true)
					})
				}

				HStack(spacing: 2) {

					Spacer()

					if !self.model.status.isEmpty
					{
						Text(self.model.status)
							.multilineTextAlignment(.leading)
							.font(.system(size: 10))
							.lineLimit(2)
							.transition(.opacity)
							.fixedSize(horizontal: false, vertical: true)
							.padding(.trailing, 4)
					}


					if self.model.spinning > 0
					{
						ActivityIndicator(size: .small)
							.frame(width: 24, height: 24)
					}

					Button(action: {
						DispatchQueue.main.async {
							// they share the same window, so we only need to fix the firstResponder once.
							self.userField?.window?.makeFirstResponder(self.userField?.window)
						}

						self.model.controller().sessionLogin(activityView: self.model as ViewModel, force: true)


					}) {
						Text("login")
					}
					.padding(.vertical, 12)
				}
			}
		}
	}
}



class IntegerNumberFormatter : NumberFormatter
{
	override func isPartialStringValid(_ partial: String,
									   newEditingString: AutoreleasingUnsafeMutablePointer<NSString?>?,
									   errorDescription: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool
	{
		return partial.isEmpty || Int(partial) != nil
	}
}
