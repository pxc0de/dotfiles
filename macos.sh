#!/usr/bin/env bash
set -u

defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string clmv
defaults write com.apple.finder FXDefaultSearchScope -string SCcf
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
chflags nohidden ~/Library

defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0
defaults write com.apple.dock tilesize -int 48
defaults write com.apple.dock orientation -string bottom
defaults write com.apple.dock magnification -bool false
defaults write com.apple.dock minimize-to-application -bool true
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock show-process-indicators -bool true
defaults write com.apple.dock persistent-apps -array
defaults write com.apple.dock persistent-others -array

defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write NSGlobalDomain AppleShowScrollBars -string Always
defaults write NSGlobalDomain AppleScrollerPagingBehavior -bool true
defaults write NSGlobalDomain AppleHighlightColor -string "0.650980 0.850980 0.580392"
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
defaults write NSGlobalDomain com.apple.springing.enabled -bool true
defaults write NSGlobalDomain com.apple.springing.delay -float 0

defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 3
defaults write NSGlobalDomain com.apple.mouse.scaling -float 3
defaults write NSGlobalDomain ContextMenuGesture -int 1
for domain in com.apple.AppleMultitouchTrackpad com.apple.driver.AppleBluetoothMultitouch.trackpad; do
    defaults write "$domain" Clicking -bool true
    defaults write "$domain" TrackpadRightClick -bool true
    defaults write "$domain" TrackpadThreeFingerDrag -bool true
done
for domain in com.apple.AppleMultitouchMouse com.apple.driver.AppleBluetoothMultitouch.mouse; do
    defaults write "$domain" MouseButtonMode -string TwoButton
done

mkdir -p ~/Desktop/Screenshots
defaults write com.apple.screencapture location -string ~/Desktop/Screenshots
defaults write com.apple.screencapture type -string png
defaults write com.apple.screencapture disable-shadow -bool true

defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -bool true
defaults write com.apple.menuextra.clock ShowDayOfWeek -bool true
defaults write com.apple.menuextra.clock ShowSeconds -bool true
defaults write com.apple.menuextra.clock FlashDateSeparators -bool true

defaults write com.apple.ActivityMonitor OpenMainWindow -bool true
defaults write com.apple.ActivityMonitor IconType -int 5
defaults write com.apple.ActivityMonitor ShowCategory -int 0

killall Finder Dock SystemUIServer ControlCenter >/dev/null 2>&1
echo "macOS defaults applied. Some take effect after a restart."
