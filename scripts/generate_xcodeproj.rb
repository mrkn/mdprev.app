#!/usr/bin/env ruby
# frozen_string_literal: true

require 'pathname'
require 'xcodeproj'

ROOT = Pathname(__dir__).join('..').realpath
PROJECT_PATH = ROOT.join('mdprev.xcodeproj')
APP_INFO_PLIST = ROOT.join('xcode', 'mdprev-Info.plist')
QUICKLOOK_INFO_PLIST = ROOT.join('xcode', 'mdprevQuickLook-Info.plist')
QUICKLOOK_ENTITLEMENTS = ROOT.join('xcode', 'mdprevQuickLook.entitlements')
ICON_FILE = ROOT.join('assets', 'app-icon', 'mdprev.icns')
APP_SOURCES_DIR = ROOT.join('src', 'mdprev')
QUICKLOOK_SOURCES_DIR = ROOT.join('src', 'MDPrevQuickLookExtension')
PACKAGE_URL = "file://#{ROOT}"

project = Xcodeproj::Project.new(PROJECT_PATH.to_s)
project.root_object.attributes['LastSwiftUpdateCheck'] = '2610'
project.root_object.attributes['LastUpgradeCheck'] = '2610'
project.root_object.compatibility_version = 'Xcode 16.0'
project.root_object.development_region = 'en'
project.root_object.known_regions = ['en', 'Base']
project.root_object.preferred_project_object_version = '77'

main_group = project.main_group
sources_group = main_group.new_group('Sources', 'src')
app_group = sources_group.new_group('mdprev', 'mdprev')
xcode_group = main_group.new_group('Xcode', 'xcode')
assets_group = main_group.new_group('Assets', 'assets')
app_icon_group = assets_group.new_group('App Icon', 'app-icon')
quicklook_group = sources_group.new_group('MDPrevQuickLookExtension', 'MDPrevQuickLookExtension')

info_ref = xcode_group.new_file(APP_INFO_PLIST.to_s)
xcode_group.new_file(QUICKLOOK_INFO_PLIST.to_s)
xcode_group.new_file(QUICKLOOK_ENTITLEMENTS.to_s)
icon_ref = app_icon_group.new_file(ICON_FILE.to_s)

app_target = project.new_target(:application, 'mdprev', :osx, '13.0')
app_target.product_name = 'mdprev'
quicklook_target = project.new_target(:app_extension, 'mdprevQuickLook', :osx, '13.0')
quicklook_target.product_name = 'mdprevQuickLook'

project_package = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
project_package.path = ROOT.to_s
project_package.relative_path = '.'
project.root_object.package_references << project_package

rendering_dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
rendering_dependency.package = project_package
rendering_dependency.product_name = 'MDPrevRendering'
app_target.package_product_dependencies << rendering_dependency

quicklook_rendering_dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
quicklook_rendering_dependency.package = project_package
quicklook_rendering_dependency.product_name = 'MDPrevRendering'
quicklook_target.package_product_dependencies << quicklook_rendering_dependency

swift_files = APP_SOURCES_DIR.children.select { |path| path.extname == '.swift' }.sort
file_refs = swift_files.map { |path| app_group.new_file(path.to_s) }
app_target.add_file_references(file_refs)
app_target.add_resources([icon_ref])

quicklook_files = QUICKLOOK_SOURCES_DIR.children.select { |path| path.extname == '.swift' && path.basename.to_s != 'main.swift' }.sort
quicklook_refs = quicklook_files.map { |path| quicklook_group.new_file(path.to_s) }
quicklook_target.add_file_references(quicklook_refs)
quicklook_target.add_system_framework('Quartz')

embed_extensions_phase = app_target.new_copy_files_build_phase('Embed App Extensions')
embed_extensions_phase.symbol_dst_subfolder_spec = :plug_ins
embed_extensions_phase.add_file_reference(quicklook_target.product_reference)
app_target.add_dependency(quicklook_target)

project.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '13.0'
end

app_target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = APP_INFO_PLIST.relative_path_from(ROOT).to_s
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'io.github.mrkn.mdprev'
  config.build_settings['PRODUCT_NAME'] = 'mdprev'
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '13.0'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/../Frameworks'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = ''
end

quicklook_target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = QUICKLOOK_INFO_PLIST.relative_path_from(ROOT).to_s
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'io.github.mrkn.mdprev.quicklook-preview'
  config.build_settings['PRODUCT_NAME'] = 'mdprevQuickLook'
  config.build_settings['SWIFT_VERSION'] = '6.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '13.0'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = QUICKLOOK_ENTITLEMENTS.relative_path_from(ROOT).to_s
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/../../Frameworks @executable_path/../Frameworks'
  config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  config.build_settings['SKIP_INSTALL'] = 'YES'
end

scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(app_target, nil, launch_target: true)
scheme.save_as(PROJECT_PATH, 'mdprev', true)

project.save
