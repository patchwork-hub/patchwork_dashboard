module StepHelper
  def community_steps
    steps = []
    is_channel_feed = params[:channel_type] == "channel_feed" || @community&.channel_feed?
    is_channel = params[:channel_type] == "channel" || @community&.channel?
    is_hub = params[:channel_type] == "hub" || @community&.hub?
    is_newsmast = params[:channel_type] == "newsmast" || @community&.newsmast?
    is_custom_channel = params[:content_type].present? ? params[:content_type] == 'custom_channel' : @community&.content_type&.custom_channel?

    if master_admin? && is_channel
      steps << { step: 0, display: 1, title: 'Choose community type', description: 'Select the type of community you want to create.' }
      steps << { step: 1, display: 2, title: 'Community information', description: 'Set up the basic details of your community.' }
      steps << { step: 2, display: 3, title: 'Admin and public feed details', description: 'Create admin accounts for your community.' }
      if is_custom_channel
        steps << { step: 3, display: 4, title: 'Add content', description: 'Populate your channel with content from across the New Social network. Here you can define rules that specify what content is included in your community.' }
        steps << { step: 4, display: 5, title: 'Filter content', description: 'Filter content from the wider network to ensure your community stays relevant.' }
        # steps << { step: 5, display: 6, title: 'Share content', description: 'Select default hashtags to help posts reach audiences beyond your channel.' }
        steps << { step: 6, display: 6, title: 'Additional information', description: 'Add your channel guidelines and any additional information to support the community.' }
      else
        steps << { step: 6, display: 4, title: 'Additional information', description: 'Add your channel guidelines and any additional information to support the community.' }
      end
    elsif user_admin? || is_channel_feed
      steps << { step: 1, display: 1, title: 'Channel information', description: 'Set up the basic details of your channel.' }
      steps << { step: 2, display: 2, title: 'Admin and public feed details', description: 'Create admin accounts for your channel.' }
      steps << { step: 3, display: 3, title: 'Add content', description: 'Populate your channel with content from across the New Social network. Here you can define rules that specify what content is included in your channel.' }
      steps << { step: 4, display: 4, title: 'Filter content', description: 'Filter content from the wider network to ensure your channel stays relevant.' }
      steps << { step: 5, display: 5, title: 'Additional information', description: 'Choose how users can access and join your channel. This determines whether users can freely join, need to request access, or must be invited.' }
    elsif newsmast_admin? || is_newsmast
      steps << { step: 1, display: 1, title: 'Newsmat channel information', description: 'Set up the basic details of your newsmast channel.' }
      steps << { step: 2, display: 2, title: 'Admin and public feed details', description: 'Create admin accounts for your newsmast channel.' }
      steps << { step: 3, display: 3, title: 'Add content', description: 'Populate your newsmast channel with content from across the New Social network. Here you can define rules that specify what content is included in your newsmast channel.' }
      steps << { step: 4, display: 4, title: 'Filter content', description: 'Filter content from the wider network to ensure your newsmast channel stays relevant.' }
    elsif organisation_admin? && is_channel
      steps << { step: 0, display: 1, title: 'Choose Channel Type', description: 'Select the type of channel you want to create.' }
      steps << { step: 1, display: 2, title: 'Community information', description: 'Set up the basic details of your channel.' }
      if is_custom_channel
        steps << { step: 3, display: 3, title: 'Add content', description: 'Populate your channel with content from across the New Social network. Here you can define rules that specify what content is included in your channel.' }
        steps << { step: 4, display: 4, title: 'Filter content', description: 'Filter content from the wider network to ensure your channel stays relevant.' }
        steps << { step: 6, display: 5, title: 'Additional information', description: 'Add your channel guidelines and any additional information to support the channel.' }
      else
        steps << { step: 6, display: 3, title: 'Additional information', description: 'Add your channel guidelines and any additional information to support the channel.' }
      end
    elsif hub_admin? || is_hub
      steps << { step: 1, display: 1, title: 'Hub information', description: 'Set up the basic details of your channel.' }
      steps << { step: 2, display: 2, title: 'Admin and public feed details', description: 'Create admin accounts for your channel.' }
      steps << { step: 6, display: 3, title: 'Additional information', description: 'Add your channel guidelines and any additional information to support the channel.' }
    end

    steps
  end

  def render_step(step_number, display_number, title, description)
    content_tag :div, class: step_class(display_number), data: { step: display_number } do
      concat(content_tag(:div, content_tag(:span, display_number, class: "small #{'step-no' if fetch_display_step > display_number}"), class: 'circle'))
      concat(content_tag(:div, content_tag(:strong, title, class: 'text-muted') + content_tag(:p, description, class: 'desc small text-muted'), class: 'label'))
    end
  end

  def step_class(step_number)
    if fetch_display_step == step_number
      'step active'
    elsif fetch_display_step > step_number
      'step done'
    else
      'step'
    end
  end

  def carousel_indicators
    total_steps = community_steps.count
    content_tag(:ol, class: 'carousel-indicators') do
      (1..total_steps).map do |display_step|
        css_class = display_step <= fetch_display_step ? 'bg-danger active' : 'bg-secondary'
        content_tag(:li, '', class: css_class, style: 'width: 65px; height: 5px;')
      end.join.html_safe
    end
  end

  def fetch_display_step
    if request.path.include?("manage_additional_information")
      if @community&.channel_feed?
        5
      else
        @community.content_type.custom_channel? ? 6 : 4
      end
    else
      step_data = community_steps.find { |s| s[:step] == @current_step }
      step_data ? step_data[:display] : 1
    end
  end

end
