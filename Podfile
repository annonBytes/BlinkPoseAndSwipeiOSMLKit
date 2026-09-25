platform :ios, '16.0'

target 'BlinkPoseAndSwipeiOSMLKit' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for BlinkPoseAndSwipeiOSMLKit

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
    end
  end
end
