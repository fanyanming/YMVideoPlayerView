@version = "0.0.1"

Pod::Spec.new do |s|
s.name         = "YMVideoPlayerView"
s.version      = @version
s.summary      = "A NICE VIDEO PLAYER"
s.description  = <<-DESC
nothing
DESC
s.homepage     = "https://github.com/fanyanming/YMVideoPlayerView"
s.license      = "MIT"
s.author             = { "Yanming" => "developerfan@outlook.com" }
s.platform     = :ios, "9.0"
s.source       = { :git => "https://github.com/fanyanming/YMVideoPlayerView.git",:tag => "v#{s.version}" }
s.source_files  = "YMVideoPlayerView/*.{h,m}"
s.framework  = "UIKit"
s.requires_arc = true

end
