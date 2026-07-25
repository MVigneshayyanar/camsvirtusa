require 'xcodeproj'
project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main group (Runner)
main_group = project.main_group.groups.find { |g| g.name == 'Runner' } || project.main_group

# Add the entitlements file reference if it doesn't exist
entitlements_path = 'Runner/Runner.entitlements'
file_ref = main_group.files.find { |f| f.path == entitlements_path }
if file_ref.nil?
  file_ref = main_group.new_file(entitlements_path)
end

# Find the Runner target
target = project.targets.find { |t| t.name == 'Runner' }

if target
  # Add the file to the target if not already there
  unless target.source_build_phase.files_references.include?(file_ref)
    # Entitlements files don't actually go into the source build phase or resources build phase,
    # they just need to be in the project file hierarchy and referenced by build settings.
  end

  # Set the build setting for CODE_SIGN_ENTITLEMENTS
  target.build_configurations.each do |config|
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = entitlements_path
  end
  puts "Successfully updated CODE_SIGN_ENTITLEMENTS for Runner target."
else
  puts "Runner target not found."
end

project.save
