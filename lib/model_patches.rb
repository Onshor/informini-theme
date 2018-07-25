# -*- encoding : utf-8 -*-
# Add a callback - to be executed before each request in development,
# and at startup in production - to patch existing app classes.
# Doing so in init/environment.rb wouldn't work in development, since
# classes are reloaded, but initialization is not run each time.
# See http://stackoverflow.com/questions/7072758/plugin-not-reloading-in-development-mode
#
Rails.configuration.to_prepare do

  OutgoingMessage.class_eval do
  #   # Add intro paragraph to new request template
    def default_letter
  #     # this line allows the default_letter text added by this
  #     # method to be replaced by the value supplied by the API
  #     # e.g. http://demo.alaveteli.org/new/tgq?default_letter=this+is+a+test
  #     return @default_letter if @default_letter
  #     return nil if self.message_type == 'followup'
      _("En vertu de loi organique n°2016-22 du 24 mars 2016, relative au droit d accès à l information et de l article n°32 de la Constitution du 27 Janvier 2014, J ai l honneur de vous adresser cette demande d accès à l information en vue de me fournir les informations ci-dessous :")
    end
  end


  User.class_eval do
    validates :terms,
              :acceptance => {
                :message => _('Please accept the Terms and Conditions'),
                :on => :create,
                :allow_nil => false
              }

    validates :status_flag,
              :presence => { :message => _('Please enter your status') }

    validates :address_line,
              :presence => { :message => _('Please enter your address') }

    validates :name,
              :format => {
                :with => /\s/,
                :message => _("Please enter your full name - it is required by law when making a request"),
                :allow_blank => true
              }


    after_save :update_censor_rules

    # The "internal admin" is a special user for internal use.
    def self.internal_admin_user
        user = User.find_by_email(AlaveteliConfiguration::contact_email)
        if user.nil?
            password = PostRedirect.generate_random_token
            user = User.new(
                :name => 'Internal admin user',
                :email => AlaveteliConfiguration.contact_email,
                :password => password,
                :password_confirmation => password,
                :address_line => 'my address',
				:status_flag => 'PP',
                :terms => '1'
            )
            user.save!
        end

        user
    end

    private

    def user_params(key = :user)
      params.require(key).permit(:name, :email, :password, :password_confirmation, :status_flag, :address_line)
    end
	  
    def update_censor_rules
      censor_rules.where(:text => address_line).first_or_create(
        :text => address_line,
        :replacement => _('REDACTED'),
        :last_edit_editor => THEME_NAME,
        :last_edit_comment => _('Updated automatically after_save')
      )
    end

  end

  InfoRequest.class_eval do

      def extension_days
          10
      end

      def waiting_response?
          described_state == "waiting_response" || described_state == "deadline_extended"
      end

      def has_extended_deadline?
          info_request_events.any?{ |event| event.described_state == 'deadline_extended' }
      end

      def reply_late_after_days
          if has_extended_deadline?
              AlaveteliConfiguration::reply_late_after_days + extension_days
          else
              AlaveteliConfiguration::reply_late_after_days
          end
      end

      def reply_very_late_after_days
          if has_extended_deadline?
              AlaveteliConfiguration::reply_very_late_after_days + extension_days
          else
              AlaveteliConfiguration::reply_very_late_after_days
          end
      end

      def date_response_required_by
          Holiday.due_date_from(date_initial_request_last_sent_at,
                                reply_late_after_days,
                                AlaveteliConfiguration::working_or_calendar_days)
      end

      def date_very_overdue_after
          Holiday.due_date_from(date_initial_request_last_sent_at,
                                reply_very_late_after_days,
                                AlaveteliConfiguration::working_or_calendar_days)
      end

  end

end
