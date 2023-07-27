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

  def title(t)
    content_for :title, t
  end

  def meta_keywords(words)
    content_for :meta_keywords, words.join(', ')
  end

  def inline_svg(filename, options = {})
    file = File.read(Rails.root.join('app', 'assets', 'images', filename))
    doc = Nokogiri::HTML::DocumentFragment.parse file
    svg = doc.at_css('svg')
    svg['class'] = options[:class] if options[:class].present?
    doc.to_html.html_safe
  end

  def pluralize_with_count(n, str)
    n == 1 ? "1 #{str}" : "#{n} #{str.pluralize(n)}"
  end

  def render_digital_ocean_referral_link(format, text, link_no_ref = nil)
    if link_no_ref.nil?
      link = 'https://m.do.co/c/758af342c81e'
      link_no_ref = 'https://www.digitalocean.com/'
    else
      link = "#{link_no_ref}?refcode=758af342c81e"
    end
    (format % [
      link_to(text, link, data: { toggle: 'tooltip' }, title: 'Literally $200 credit for the first 2 months (as of 2023 July 16)'),
      link_to('no referral', link_no_ref),
    ]).html_safe
  end

  def render_server_ip_address(server, fallback = nil)
    if server.remote.error?
      return 'Error'
    end
    if server.remote.exists? && server.remote.ip_address
      return "#{server.host_name} (or #{server.remote.ip_address})"
    end
    fallback || "#{server.host_name} (Not running)"
  end

  def render_server_status(server)
    if server.pending_operation
      return server.pending_operation
    end
    if server.remote.error?
      return 'Error'
    end
    if server.running?
      return 'Active'
    end
    'Not running'
  end
end
