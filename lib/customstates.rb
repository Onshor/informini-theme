# -*- encoding : utf-8 -*-
# See `doc/THEMES.md` for more explanation of this file
# This example adds a "transferred" state to requests.

module InfoRequestCustomStates
  def self.included(base)
    base.extend(ClassMethods)
  end

  # Work out what the situation of the request is. In addition to
  # values of self.described_state, in base Alaveteli can return
  # these (calculated) values:
  #   waiting_classification
  #   waiting_response_overdue
  #   waiting_response_very_overdue
  def theme_calculate_status
    return 'waiting_classification' if awaiting_description
    return described_state unless waiting_response?
    return 'waiting_response_very_overdue' if
        Time.now.strftime("%Y-%m-%d") > date_very_overdue_after.strftime("%Y-%m-%d")
    return 'waiting_response_overdue' if
        Time.now.strftime("%Y-%m-%d") > date_response_required_by.strftime("%Y-%m-%d")
    return 'deadline_extended' if has_extended_deadline?
    return 'waiting_response'
  end

  # Mixin methods for InfoRequest
  module ClassMethods
    def theme_display_status(status)
      if status == 'deadline_extended'
        _("Deadline extended.")
      else
        raise _("unknown status ") + status
      end
    end

    def theme_extra_states
      return ['deadline_extended']
    end
  end
end

module RequestControllerCustomStates
  def theme_describe_state(info_request)
    # called after the core describe_state code.  It should
    # end by raising an error if the status is unknown
    if info_request.calculate_status == 'deadline_extended'
      flash[:notice] = _("<p>Thank you! Hopefully your wait isn't too long.</p> <p>By law, you should get a response promptly, and normally before the end of <strong>
      {{date_response_required_by}}</strong>.</p>",
        :date_response_required_by => view_context.simple_date(info_request.date_response_required_by))
      redirect_to request_url(info_request)
    else
      raise "unknown calculate_status " + info_request.calculate_status
    end
  end
end
