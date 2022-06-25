#!/sbin/sh
# Shell Script EDIFY Replacement

ProgressBarValues="
ExtraFiles=0.02
GooglePlayStore=0.04
GoogleServicesFramework=0.06
GoogleContactsSyncAdapter=0.08
GoogleCalendarSyncAdapter=0.1
GmsCore=0.12
DigitalWellbeing=0.14
GoogleMessages=0.16
GoogleDialer=0.18
GoogleContacts=0.2
CarrierServices=0.22
GoogleClock=0.24
SetupWizard=0.26
GoogleRestore=0.28
GoogleOneTimeInitializer=0.3
AndroidMigratePrebuilt=0.32
GoogleCalculator=0.34
Drive=0.36
GoogleMaps=0.38
GoogleLocationHistory=0.4
Gmail=0.42
GooglePhotos=0.44
DeviceHealthServices=0.46
Velvet=0.48
Assistant=0.5
GBoard=0.52
PixelLauncher=0.54
DevicePersonalizationServices=0.56
QuickAccessWallet=0.58
GoogleWallpaper=0.6
GoogleFiles=0.62
StorageManager=0.64
DocumentsUIGoogle=0.66
GoogleRecorder=0.68
GoogleCalendar=0.7
MarkupGoogle=0.72
GoogleFeedback=0.74
GooglePartnerSetup=0.76
GoogleSounds=0.78
AndroidDevicePolicy=0.8
"

Core="
ExtraFiles,837,product
GooglePlayStore,56748,product
GoogleServicesFramework,7445,product
GoogleContactsSyncAdapter,2817,product
GoogleCalendarSyncAdapter,2451,product
GmsCore,117324,product
"

DigitalWellbeing="
DigitalWellbeing,15720,product
"

GoogleMessages="
GoogleMessages,66950,product
"

GoogleDialer="
GoogleDialer,57233,product
"

GoogleContacts="
GoogleContacts,16183,product
"

CarrierServices="
CarrierServices,8472,product
"

GoogleClock="
GoogleClock,11358,product
"

SetupWizard="
SetupWizard,8273,product
GoogleRestore,9501,product
GoogleOneTimeInitializer,189,system_ext
AndroidMigratePrebuilt,0,product
"

GoogleCalculator="
GoogleCalculator,4326,product
"

Drive="
Drive,26867,product
"

GoogleMaps="
GoogleMaps,56434,product
"

GoogleLocationHistory="
GoogleLocationHistory,50,product
"

Gmail="
Gmail,48444,product
"

GooglePhotos="
GooglePhotos,94474,product
"

DeviceHealthServices="
DeviceHealthServices,7394,product
"

GoogleSearch="
Velvet,237094,product
Assistant,1390,product
"

GBoard="
GBoard,184284,product
"

PixelLauncher="
PixelLauncher,13625,system_ext
DevicePersonalizationServices,86014,product
QuickAccessWallet,507,product
GoogleWallpaper,6992,system_ext
"

GoogleFiles="
GoogleFiles,19514,product
StorageManager,10511,system_ext
DocumentsUIGoogle,6453,product
"

GoogleRecorder="
GoogleRecorder,82020,product
"

GoogleCalendar="
GoogleCalendar,34604,product
"

MarkupGoogle="
MarkupGoogle,5793,product
"

GoogleFeedback="
GoogleFeedback,693,system_ext
"

GooglePartnerSetup="
GooglePartnerSetup,507,product
"

GoogleSounds="
GoogleSounds,4072,product
"

AndroidDevicePolicy="
AndroidDevicePolicy,8789,product
"

install_app_set "Core" "$Core"
install_app_set "DigitalWellbeing" "$DigitalWellbeing"
install_app_set "GoogleMessages" "$GoogleMessages"
install_app_set "GoogleDialer" "$GoogleDialer"
install_app_set "GoogleContacts" "$GoogleContacts"
install_app_set "CarrierServices" "$CarrierServices"
install_app_set "GoogleClock" "$GoogleClock"
install_app_set "SetupWizard" "$SetupWizard"
install_app_set "GoogleCalculator" "$GoogleCalculator"
install_app_set "Drive" "$Drive"
install_app_set "GoogleMaps" "$GoogleMaps"
install_app_set "GoogleLocationHistory" "$GoogleLocationHistory"
install_app_set "Gmail" "$Gmail"
install_app_set "GooglePhotos" "$GooglePhotos"
install_app_set "DeviceHealthServices" "$DeviceHealthServices"
install_app_set "GoogleSearch" "$GoogleSearch"
install_app_set "GBoard" "$GBoard"
install_app_set "PixelLauncher" "$PixelLauncher"
install_app_set "GoogleFiles" "$GoogleFiles"
install_app_set "GoogleRecorder" "$GoogleRecorder"
install_app_set "GoogleCalendar" "$GoogleCalendar"
install_app_set "MarkupGoogle" "$MarkupGoogle"
install_app_set "GoogleFeedback" "$GoogleFeedback"
install_app_set "GooglePartnerSetup" "$GooglePartnerSetup"
install_app_set "GoogleSounds" "$GoogleSounds"
install_app_set "AndroidDevicePolicy" "$AndroidDevicePolicy"

set_progress 1.00

exit_install

