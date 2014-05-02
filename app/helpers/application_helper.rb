module ApplicationHelper

	def panel_with_heading(title, &block)
		result = content_tag :div, class: 'panel panel-default' do
			inner_html = content tag :div, class: 'panel-heading' do
				content_tag :h3, title, class: 'panel-title'
			end
			inner_html += content_tag div, class: 'panel-body' do
				yield
			end
			inner_html
		end
		result.html_safe
	end
end
