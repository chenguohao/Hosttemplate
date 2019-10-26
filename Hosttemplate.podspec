Pod::Spec.new do |spec|
  spec.name         = 'Hosttemplate'
  spec.version      = '1.0.0'
  spec.license      = { :type => 'BSD' }
  spec.authors      = { 'MTP' => 'mtp@huya.com' }
  spec.summary      = 'Modular'
  spec.homepage     = 'https://github.com/hejun-lyne'
  spec.source       = { :git => 'https://github.com/chenguohao/Hosttemplate.git' }
                                
  spec.ios.deployment_target = '9.0'
  spec.static_framework = true
  spec.default_subspec = 'All'

  spec.subspec 'All' do |ss|
    ss.source_files = '*.h','Classes/*.{h,m}'
  end

end