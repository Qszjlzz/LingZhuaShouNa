#!/usr/bin/env ruby

ROOT = File.expand_path("..", __dir__)
USER_GEM_ROOT = File.expand_path("~/.gem/ruby/2.6.0/gems")

[
  File.join(USER_GEM_ROOT, "xcodeproj-1.28.1/lib"),
  File.join(USER_GEM_ROOT, "claide-1.1.0/lib"),
  File.join(USER_GEM_ROOT, "colored2-3.1.2/lib"),
  File.join(USER_GEM_ROOT, "nanaimo-0.4.4/lib"),
  File.join(USER_GEM_ROOT, "nanaimo-0.4.0/lib"),
  File.join(USER_GEM_ROOT, "atomos-0.1.3/lib"),
  File.join(USER_GEM_ROOT, "rexml-3.4.4/lib")
].each do |path|
  $LOAD_PATH.unshift(path) if Dir.exist?(path) && !$LOAD_PATH.include?(path)
end

require "xcodeproj"
require "fileutils"

PROJECT_NAME = "SmartPaw"
PROJECT_PATH = File.join(ROOT, "#{PROJECT_NAME}.xcodeproj")
DEPLOYMENT_TARGET = "18.0"

def ensure_group(parent, name)
  parent.children.find { |child| child.is_a?(Xcodeproj::Project::Object::PBXGroup) && child.display_name == name } ||
    parent.new_group(name, name)
end

def add_directory(group, absolute_path, target)
  return unless Dir.exist?(absolute_path)

  Dir.children(absolute_path).sort.each do |entry|
    next if entry.start_with?(".")

    child_absolute = File.join(absolute_path, entry)
    if File.directory?(child_absolute)
      if [".xcassets", ".mlpackage"].include?(File.extname(entry))
        file_ref = group.new_file(entry)
        target.resources_build_phase.add_file_reference(file_ref, true)
        next
      end

      child_group = ensure_group(group, entry)
      add_directory(child_group, child_absolute, target)
      next
    end

    file_ref = group.new_file(entry)
    if File.extname(entry) == ".swift"
      target.source_build_phase.add_file_reference(file_ref, true)
    else
      target.resources_build_phase.add_file_reference(file_ref, true)
    end
  end
end

FileUtils.rm_rf(PROJECT_PATH)
project = Xcodeproj::Project.new(PROJECT_PATH)
project.root_object.attributes["LastSwiftUpdateCheck"] = "1640"
project.root_object.attributes["LastUpgradeCheck"] = "1640"

app_target = project.new_target(:application, PROJECT_NAME, :ios, DEPLOYMENT_TARGET)
test_target = project.new_target(:unit_test_bundle, "#{PROJECT_NAME}Tests", :ios, DEPLOYMENT_TARGET)

[app_target, test_target].each do |target|
  target.build_configurations.each do |config|
    settings = config.build_settings
    settings["SWIFT_VERSION"] = "5.0"
    settings["IPHONEOS_DEPLOYMENT_TARGET"] = DEPLOYMENT_TARGET
    settings["TARGETED_DEVICE_FAMILY"] = "1"
    settings["CODE_SIGNING_ALLOWED[sdk=iphonesimulator*]"] = "NO"
    settings["GENERATE_INFOPLIST_FILE"] = "YES"
    settings["LD_RUNPATH_SEARCH_PATHS"] = "$(inherited) @executable_path/Frameworks @loader_path/Frameworks"
    settings["SWIFT_EMIT_LOC_STRINGS"] = "NO"
  end
end

app_target.build_configurations.each do |config|
  settings = config.build_settings
  settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.qszjlzz.smartpaw"
  settings["PRODUCT_NAME"] = PROJECT_NAME
  settings["PRODUCT_MODULE_NAME"] = PROJECT_NAME
  settings["ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME"] = "AccentColor"
  settings["ENABLE_PREVIEWS"] = "YES"
  settings["INFOPLIST_KEY_CFBundleDisplayName"] = "灵爪收纳"
  settings["INFOPLIST_KEY_CFBundleName"] = "SmartPaw"
  settings["INFOPLIST_KEY_LSApplicationCategoryType"] = "public.app-category.productivity"
  settings["INFOPLIST_KEY_NSCameraUsageDescription"] = "用于扫描杂乱空间并生成收纳规划。"
  settings["INFOPLIST_KEY_NSPhotoLibraryUsageDescription"] = "用于保存或选择收纳前后对比图片。"
  settings["INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents"] = "YES"
  settings["INFOPLIST_KEY_UILaunchScreen_Generation"] = "YES"
  settings["INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone"] = "UIInterfaceOrientationPortrait"
  settings["CURRENT_PROJECT_VERSION"] = "1"
  settings["MARKETING_VERSION"] = "1.0"
  settings["CODE_SIGN_STYLE"] = "Automatic"
end

test_target.build_configurations.each do |config|
  settings = config.build_settings
  settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.qszjlzz.smartpaw.tests"
  settings["PRODUCT_NAME"] = "#{PROJECT_NAME}Tests"
  settings["PRODUCT_MODULE_NAME"] = "#{PROJECT_NAME}Tests"
  settings["TEST_TARGET_NAME"] = PROJECT_NAME
  settings["TEST_HOST"] = "$(BUILT_PRODUCTS_DIR)/#{PROJECT_NAME}.app/#{PROJECT_NAME}"
  settings["BUNDLE_LOADER"] = "$(TEST_HOST)"
end

test_target.add_dependency(app_target)

main_group = project.main_group
%w[App Models Services Features Resources].each do |group_name|
  group = ensure_group(main_group, group_name)
  add_directory(group, File.join(ROOT, group_name), app_target)
end

test_group = ensure_group(main_group, "SmartPawTests")
add_directory(test_group, File.join(ROOT, "SmartPawTests"), test_target)

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app_target)
scheme.set_launch_target(app_target)
scheme.add_test_target(test_target)
scheme.save_as(PROJECT_PATH, PROJECT_NAME, true)

project.save
