require 'rails_helper'
require 'tariff_synchronizer'

describe TariffSynchronizer::Logger, truncation: true do
  include BankHolidaysHelper

  before(:all) { WebMock.disable_net_connect! }

  after(:all)  { WebMock.allow_net_connect! }

  before { tariff_synchronizer_logger_listener }

  describe '#missing_updates' do
    let(:not_found_response) { build :response, :not_found }

    before do
      stub_holidays_gem_between_call
      create :chief_update, :missing, issue_date: Date.current.ago(2.days)
      create :chief_update, :missing, issue_date: Date.current.ago(3.days)
      allow(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform)
                                            .and_return(not_found_response)
      TariffSynchronizer::ChiefUpdate.sync
    end

    it 'logs a warn event' do
      expect(@logger.logged(:warn).size).to be > 1
      expect(@logger.logged(:warn).to_s).to match(/Missing/)
    end

    it 'sends a warning email' do
      expect(ActionMailer::Base.deliveries).not_to be_empty
      email = ActionMailer::Base.deliveries.last
      expect(email.encoded).to match(/missing/)
    end
  end

  describe '#rollback_lock_error' do
    before do
      expect(TradeTariffBackend).to receive(
        :with_redis_lock,
      ).and_raise(Redlock::LockError)

      TariffSynchronizer.rollback(Date.current, true)
    end

    it 'logs a warn event' do
      expect(@logger.logged(:warn).size).to be >= 1
      expect(@logger.logged(:warn).first.to_s).to match(/acquire Redis lock/)
    end
  end

  describe '#apply_lock_error' do
    before do
      expect(TradeTariffBackend).to receive(
        :with_redis_lock,
      ).and_raise(Redlock::LockError)

      TariffSynchronizer.apply
    end

    it 'logs a warn event' do
      expect(@logger.logged(:warn).size).to be >= 1
      expect(@logger.logged(:warn).first.to_s).to match(/acquire Redis lock/)
    end
  end
end
