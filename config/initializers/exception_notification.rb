Guides::Application.config.middleware.use ExceptionNotifier,
  :email_prefix => "[Guides] ",
  :sender_address => %{"Winston Smith-Churchill" <winston@alphagov.co.uk>},
  :exception_recipients => %w{dev@alphagov.co.uk}