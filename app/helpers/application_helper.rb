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

  def render_minecraft_ip_address(minecraft, fallback = nil)
    if minecraft.server.remote.error?
      return 'Error'
    end
    if minecraft.server.remote.exists? && minecraft.server.remote.ip_address
      return "#{minecraft.domain}.#{Gamocosm::USER_SERVERS_DOMAIN} (or #{minecraft.server.remote.ip_address})"
    end
    return fallback || 'Not running'
  end

  def render_server_status(minecraft)
    if minecraft.server.pending_operation
      return minecraft.server.pending_operation
    end
    if minecraft.server.remote.error?
      return 'Error'
    end
    if minecraft.server.running?
      return minecraft.server.remote.status
    end
    return 'Not running'
  end

  def render_digital_ocean_referral_link(format, text, link, link_no_ref)
    return (format % [link_to(text, link, data: { toggle: 'tooltip' }, title: '$10 credit when you sign up'), link_to('*', link_no_ref, data: { toggle: 'tooltip' }, title: 'no referral (no $10 promo)')]).html_safe
  end

  def pluralize_with_count(n, str)
    return n == 1 ? "1 #{str}" : "#{n} #{str.pluralize(n)}"
  end

  def title(t)
    content_for :title, t
  end

  def meta_keywords(words)
    content_for :meta_keywords, words.join(', ')
  end
end
