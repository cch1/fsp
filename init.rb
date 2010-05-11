# Include hook code here
ActionView::Base.send :include, FSP::Helper
ActionController::Base.send :include, FSP::ControllerMethods