module ApplicationHelper

	def panel_with_heading(title, &block)
		result = content_tag :div, class: 'panel panel-default' do
			inner_html = content_tag :div, class: 'panel-heading' do
				content_tag :h3, title, class: 'panel-title'
			end
			inner_html += content_tag :div, class: 'panel-body' do
				yield
			end
			inner_html
		end
		result.html_safe
	end

	def render_server_ip_address(server)
		if server.droplet && server.droplet.ip_address
			return server.droplet.ip_address.to_s
		end
		return 'Not available'
	end
end
