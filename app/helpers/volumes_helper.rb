module VolumesHelper
  def breadcrumb_back_to_volumes
    link_to volumes_path, class: 'basic-breadcrumb' do
      'Volumes <span class="fa fa-angle-right"></span>'.html_safe
    end
  end
end
