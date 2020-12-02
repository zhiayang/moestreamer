// SettingsView.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import Combine
import SwiftUI
import Foundation

private let settingsFrameWidth: CGFloat = 280

private func changeControllerFor(_ oldController: Binding<ServiceController>, backend: MusicBackend)
{
	let vm = oldController.wrappedValue.getViewModel()

	let con: ServiceController
	switch(backend)
	{
		case .ListenMoe:
			con = ListenMoeController(viewModel: vm)

		case .LocalMusic:
			con = LocalMusicController(viewModel: vm)
	}

	if let vm = vm {
		con.setViewModel(viewModel: vm)
		if let mm = vm as? MainModel {
			mm.onSongChange(song: nil)
			mm.isPlaying = false
		}
	}

	oldController.wrappedValue.stop()
	oldController.wrappedValue = con

	globalMediaKeyHandler.setController(con)
}

struct SettingsView : View
{
	@Environment(\.colorScheme)
	var colourScheme: ColorScheme

	@Binding var musicCon: ServiceController

	// swiftui is fucking dumb. nothing works properly.
	@State var backend: MusicBackend = Settings.getKE(.musicBackend())
	@ObservedObject var backendSetting = SavedSettingModel<MusicBackend>(.musicBackend(),
																		 getter: Settings.getKE,
																		 setter: Settings.setKE)

	@ObservedObject var shouldUseDiscord = SavedSettingModel<Bool>(.shouldUseDiscordPresence())

	init(musicCon: Binding<ServiceController>)
	{
		self._musicCon = musicCon
	}

	var body: some View {
		ZStack() {
			VStack(spacing: 16) {
				PrimarySettingsView(con: self.$musicCon, discord: self.$shouldUseDiscord.value)

				HStack() {
					Text("music source")
						.padding(.leading, 2)
						.tooltip("which music backend to use")

					PopupButton(selectedValue: self.$backend, items: MusicBackend.values, onChange: {
						if self.backendSetting.value != $0
						{
							self.backendSetting.value = $0

							// time to change the controller.
							changeControllerFor(self.$musicCon, backend: self.backend)
						}
					}).frame(width: 140)

				}.padding(.top, 4)

				if self.backend == .ListenMoe()
				{
					ListenMoeSettingsView(con: self.$musicCon)
				}
				else
				{
					LocalMusicSettingsView(con: self.$musicCon)
				}

				if self.shouldUseDiscord.value
				{
					DiscordSettingsView()
				}
			}
		}
		.frame(width: settingsFrameWidth)
		.padding(.all, 12)
	}
}


private struct PrimarySettingsView : View
{
	@ObservedObject var shouldAutoRefresh       = SavedSettingModel<Bool>(.shouldAutoRefresh())
	@ObservedObject var shouldUseKeyboard       = SavedSettingModel<Bool>(.shouldUseKeyboardShortcuts())
	@ObservedObject var shouldUseMediaKeys      = SavedSettingModel<Bool>(.shouldUseMediaKeys())
	@ObservedObject var shouldResumeOnWake      = SavedSettingModel<Bool>(.shouldResumeOnWake())
	@Binding var shouldUseDiscord: Bool;

	@ObservedObject var streamBufferMs = SavedSettingModel<Int>(.streamBufferMs(), willset: {
		return (100 ... 10000).contains($0)
	})

	@ObservedObject var audioVolumeScale = SavedSettingModel<Int>(.audioVolumeScale(), willset: {
		return (1 ... 100).contains($0)
	})

	@Binding var controller: ServiceController

	init(con: Binding<ServiceController>, discord: Binding<Bool>)
	{
		self._controller = con
		self._shouldUseDiscord = discord
	}

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
				Toggle(isOn: Binding(get: { self.shouldUseMediaKeys.value },
									 set: {
										self.shouldUseMediaKeys.value = $0
										globalMediaKeyHandler.enable(self.shouldUseMediaKeys.value, musicCon: controller)
				})) {
					Text("use media keys")
						.padding(.leading, 2)
					 	.tooltip("use the media keys (f7-f9, or touchbar equivalent) to control playback")
				}
			}

			HStack() {
				Toggle(isOn: self.$shouldResumeOnWake.value) {
					Text("resume on wake")
						.padding(.leading, 2)
						.tooltip("resume playback when waking from sleep")
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
				Toggle(isOn: self.$shouldUseDiscord) {
					Text("discord rich presence")
						.padding(.leading, 2)
						.tooltip("show now playing information on discord through rich presence")
				}
			}.padding(.bottom, 4)

			HStack() {
				Text("volume scale (%)")
					.padding(.leading, 2)
					.tooltip("the scale of the volume slider")
					.frame(width: 120)

				Stepper(value: self.$audioVolumeScale.value, in: 1 ... 100, step: 1) {
					TextField("", text: Binding(get: {
						String(self.audioVolumeScale.value)
					}, set: { new in
						if let int = Int(new) {
							self.audioVolumeScale.value = int
						}
					})).frame(width: 48)
				}
			}

			HStack() {
				Text("stream buffer (ms)")
					.padding(.leading, 2)
					.tooltip("how much audio to buffer (effectively stream delay)")
					.frame(width: 120)

				Stepper(value: self.$streamBufferMs.value, in: 100 ... 10000, step: 100) {
					TextField("", text: Binding(get: {
						String(self.streamBufferMs.value)
					}, set: { new in
						if let int = Int(new) {
							self.streamBufferMs.value = int
						}
					})).frame(width: 48)
				}

			}

		}.frame(width: settingsFrameWidth)
	}
}



private struct LocalMusicSettingsView : View
{
	@ObservedObject
	var playlist = SavedSettingModel<String>(.localMusicPlaylist())

	@ObservedObject
	var shuffle = SavedSettingModel<ShuffleBehaviour>(.localMusicShuffle(),
													  getter: Settings.getKE,
													  setter: Settings.setKE)

	@Binding var controller: ServiceController

	init(con: Binding<ServiceController>)
	{
		self._controller = con
	}

	private func getPlaylists() -> [String]
	{
		if let con = self.controller as? LocalMusicController {
			return con.getAllPlaylists()
		}

		return [ ]
	}

	var body: some View {
		VStack(spacing: 0) {
			Text("iTunes settings")
			Divider().frame(width: 200).padding(.bottom, 8).padding(.top, 1)

			HStack() {
				Text("playlist")
					.padding(.leading, 2)
					.tooltip("which iTunes playlist to use")

				PopupButton(selectedValue: self.$playlist.value, items: self.getPlaylists(), onChange: {
					if let con = self.controller as? LocalMusicController {
						con.setCurrentPlaylist(playlist: $0)
					}
				}).frame(width: 140)
			}.padding(.bottom, 4)

			HStack() {
				Text("shuffle")
					.padding(.leading, 2)
					.tooltip("how to shuffle the playlist")

				PopupButton(selectedValue: self.$shuffle.value, items: ShuffleBehaviour.values, onChange: {
					if let con = self.controller as? LocalMusicController {
						con.setShuffleBehaviour(as: $0)
					}
				}).frame(width: 140)
			}.padding(.bottom, 4)
		}
	}
}


private struct DiscordSettingsView : View
{
	@State var appIdField: NSTextField! = nil
	@State var tokenField: NSSecureTextField! = nil

	@ObservedObject
	var discordAppId = SavedSettingModel<String>(.discordAppId())

	@ObservedObject
	var discordToken = SavedSettingModel<String>(.discordUserToken(), disableLogging: true,
												 getter: Settings.getKeychain,
												 setter: Settings.setKeychain)

	var body: some View {
		VStack(spacing: 3) {
			Text("discord settings")
			Divider().frame(width: 200).padding(.bottom, 8).padding(.top, 1)

			HStack() {
				Text("appid").frame(width: 40)
				BetterTextField<NSTextField>(placeholder: "", text: self.$discordAppId.value, field: self.$appIdField)
			}

			HStack() {
				Text("token").frame(width: 40)
				BetterTextField<NSSecureTextField>(placeholder: "", text: self.$discordToken.value, field: self.$tokenField)
			}
		}.frame(width: 240)
	}
}


private class SpinnerModel : ObservableObject, ViewModel
{
	@Published var dummy: Bool = false

	@Published var status: String = ""
	@Published var spinning: Int = 0

	private var musicCon: ServiceController

	init(controller: ServiceController)
	{
		self.musicCon = controller
	}

	func controller() -> ServiceController
	{
		return self.musicCon
	}

	func onSongChange(song: Song?)
	{
		// do nothing.
	}

	func poke()
	{
		DispatchQueue.main.async {
			self.dummy.toggle()
		}
	}

	func spin()
	{
		DispatchQueue.main.async {
			withAnimation(.easeIn(duration: 0.35)) {
				self.spinning += 1
			}
		}
	}

	func unspin()
	{
		DispatchQueue.main.async {
			withAnimation(.easeOut(duration: 0.35)) {
				if self.spinning > 0 {
					self.spinning -= 1
				}
			}
		}
	}

	func setStatus(s: String, timeout: TimeInterval? = nil)
	{
		DispatchQueue.main.async {
			withAnimation(.easeIn(duration: 0.25)) {
				self.status = s
			}
		}

		if let t = timeout {
			// can't update the UI in background threads.
			DispatchQueue.main.asyncAfter(deadline: .now() + t) {
				withAnimation(.easeOut(duration: 0.45)) {
					self.status = ""
				}
			}
		}
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

	@ObservedObject var shouldAutoLogin = SavedSettingModel<Bool>(.listenMoeAutoLogin())

	@State var userField: NSTextField! = nil
	@State var passField: NSSecureTextField! = nil

	// this is separate from the one on the main window.
	@ObservedObject var model: SpinnerModel

	init(con: Binding<ServiceController>)
	{
		self.model = SpinnerModel(controller: con.wrappedValue)
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

							if let con = self.model.controller() as? ListenMoeController {
								con.sessionLogin(activityView: self.model as ViewModel, force: true)
							}
					})
				}

				HStack(spacing: 2) {

					Toggle(isOn: self.$shouldAutoLogin.value) {
						Text("automatically login")
							.padding(.leading, 2)
							.tooltip("login to services automatically")
					}
					.padding(.leading, 4)

					Spacer()

					if self.model.spinning > 0
					{
						ActivityIndicator(size: .small)
							.frame(width: 20, height: 20)
					}

					Button(action: {
						DispatchQueue.main.async {
							// they share the same window, so we only need to fix the firstResponder once.
							self.userField?.window?.makeFirstResponder(self.userField?.window)
						}

						if let con = self.model.controller() as? ListenMoeController {
							con.sessionLogin(activityView: self.model as ViewModel, force: true)
						}
					}) {
						Text("login")
					}
					.padding(.bottom, 2)
				}

				HStack() {
					Spacer()
					if !self.model.status.isEmpty
					{
						Text(self.model.status)
							.multilineTextAlignment(.leading)
							.font(.system(size: 10))
							.lineLimit(1)
							.transition(.opacity)
							.padding(.trailing, 4)
					}
				}
				.frame(height: 12)
				.padding(.vertical, 2)
			}
		}
	}
}

