require 'spec_helper'
require 'tariff_synchronizer'
require 'active_support/log_subscriber/test_helper'

describe TariffSynchronizer::Logger do
  include ActiveSupport::LogSubscriber::TestHelper

  before(:all) { WebMock.disable_net_connect! }
  after(:all)  { WebMock.allow_net_connect! }

  before {
    setup # ActiveSupport::LogSubscriber::TestHelper.setup

    TariffSynchronizer::Logger.attach_to :tariff_synchronizer
    TariffSynchronizer::Logger.logger = @logger
  }

  describe '#download logging' do
    before {
      TariffSynchronizer::TaricUpdate.expects(:sync).returns(true)
      TariffSynchronizer::ChiefUpdate.expects(:sync).returns(true)
      TariffSynchronizer.expects(:sync_variables_set?).returns(true)

      TariffSynchronizer.download
    }

    it 'logs an info event' do
      @logger.logged(:info).size.should eq 1
      @logger.logged(:info).last.should =~ /Finished downloading/
    end
  end

  describe '#config_error logging' do
    before {
      TariffSynchronizer.expects(:sync_variables_set?).returns(false)

      TariffSynchronizer.download
    }

    it 'logs an info event' do
      @logger.logged(:error).size.should eq 1
      @logger.logged(:error).last.should =~ /Missing/
    end
  end

  describe '#failed_updates_present logging' do
    let(:update_stubs) { stub(any?: true, map: []) }

    before {
      TariffSynchronizer::BaseUpdate.stubs(:failed).returns(update_stubs)

      TariffSynchronizer.apply
    }

    it 'logs and error event' do
      @logger.logged(:error).size.should eq 1
      @logger.logged(:error).last.should =~ /found failed updates/
    end

    it 'sends email error email' do
      ActionMailer::Base.deliveries.should_not be_empty
      email = ActionMailer::Base.deliveries.last
      email.encoded.should =~ /File names/
    end
  end

  describe '#apply logging' do
    after {
      # reset to previous(default) state
      TariffSynchronizer::Logger.conformance_errors = []
    }

    context 'pending update present' do
      let(:example_date)  { Date.today }
      let!(:taric_update) { create :taric_update, example_date: example_date }

      before {
        prepare_synchronizer_folders
        create_taric_file :pending, example_date

        Footnote.unrestrict_primary_key
        Footnote.set_active_validations []

        TariffSynchronizer.apply
      }

      after  { purge_synchronizer_folders }

      it 'logs and info event' do
        @logger.logged(:info).size.should be > 0
        @logger.logged(:info).last.should =~ /Finished applying/
      end

      it 'sends success email' do
        ActionMailer::Base.deliveries.should_not be_empty
        email = ActionMailer::Base.deliveries.last
        email.encoded.should =~ /successfully applied/
        email.encoded.should =~ /#{taric_update.filename}/
      end

      it 'informs that no conformance errors were found' do
        ActionMailer::Base.deliveries.should_not be_empty
        email = ActionMailer::Base.deliveries.last
        email.encoded.should =~ /No conformance errors found/
      end
    end

    context 'no pending updates present' do
      before {
        ActionMailer::Base.deliveries = []
        TariffSynchronizer.apply
      }

      it 'logs and info event' do
        @logger.logged(:info).size.should eq 0
      end

      it 'does not send success email' do
        ActionMailer::Base.deliveries.should be_empty
      end
    end

    context 'with conformance errors present' do
      let(:example_date)  { Date.today }
      let!(:taric_update) { create :taric_update, example_date: example_date }

      before {
        prepare_synchronizer_folders
        create_taric_file :pending, example_date

        TariffSynchronizer::Logger.conformance_errors << build(:measure, validity_start_date: Date.today, validity_end_date: Date.today.ago(1.year))
        TariffSynchronizer.apply
      }

      after {
        purge_synchronizer_folders
      }

      it 'logs and info event' do
        @logger.logged(:info).size.should be > 1
      end

      it 'sends email with conformance error descriptions' do
        ActionMailer::Base.deliveries.should_not be_empty

        last_email_content = ActionMailer::Base.deliveries.last.encoded
        last_email_content.should_not =~ /No conformance errors found/
        last_email_content.should =~ /must be less then or equal to end date/
      end
    end
  end

  describe '#failed_update logging' do
    let(:mock_pending_update) { mock(issue_date: Date.today,
                                     update_priority: 1,
                                     file_path: '/') }


    before {
      class MockException < StandardError
        def backtrace
          []
        end
      end

      mock_pending_update.expects(:apply).raises(TaricImporter::ImportException.new("", MockException.new))

      TariffSynchronizer::PendingUpdate.expects(:all).returns([mock_pending_update])
      rescuing {
        TariffSynchronizer.apply
      }
    }

    it 'logs and info event' do
      @logger.logged(:error).size.should eq 1
      @logger.logged(:error).last.should =~ /Update failed/
    end

    it 'sends email error email' do
      ActionMailer::Base.deliveries.should_not be_empty
      email = ActionMailer::Base.deliveries.last
      email.encoded.should =~ /Backtrace/
    end

    it 'email includes information about original exception' do
      ActionMailer::Base.deliveries.should_not be_empty
      email = ActionMailer::Base.deliveries.last
      email.encoded.should =~ /MockException/
    end
  end

  describe '#failed_download logging' do
    before {
       TariffSynchronizer.retry_count = 0
       TariffSynchronizer.stubs(:sync_variables_set?).returns(true)

       Curl::Easy.any_instance
                 .expects(:perform)
                 .raises(Curl::Err::HostResolutionError)

      rescuing { TariffSynchronizer.download }
    }

    it 'logs and info event' do
      @logger.logged(:error).size.should eq 1
      @logger.logged(:error).last.should =~ /Download failed/
    end

    it 'sends email error email' do
      ActionMailer::Base.deliveries.should_not be_empty
      email = ActionMailer::Base.deliveries.last
      email.encoded.should =~ /Backtrace/
    end

    it 'email includes information about exception' do
      email = ActionMailer::Base.deliveries.last
      email.encoded.should =~ /Curl::Err::HostResolutionError/
    end
  end

  describe '#rebuild logging' do
    before {
      TariffSynchronizer::TaricUpdate.expects(:rebuild).returns(true)
      TariffSynchronizer::ChiefUpdate.expects(:rebuild).returns(true)

      TariffSynchronizer.rebuild
    }

    it 'logs an info event' do
      @logger.logged(:info).size.should eq 1
      @logger.logged(:info).last.should =~ /Rebuilding/
    end
  end

  describe '#retry_exceeded logging' do
    let(:failed_response) { build :response, :retry_exceeded }

    before {
      TariffSynchronizer::ChiefUpdate.expects(:download_content).returns(failed_response)

      TariffSynchronizer::ChiefUpdate.download(Date.today)
    }

    it 'logs a warning event' do
      @logger.logged(:warn).size.should eq 1
      @logger.logged(:warn).last.should =~ /Download retry/
    end

    it 'sends a warning email' do
      ActionMailer::Base.deliveries.should_not be_empty
      email = ActionMailer::Base.deliveries.last
      email.encoded.should =~ /Retry count exceeded/
    end
  end

  describe '#not_found logging' do
    let(:not_found_response) { build :response, :not_found }

    before {
      TariffSynchronizer::ChiefUpdate.expects(:download_content).returns(not_found_response)

      TariffSynchronizer::ChiefUpdate.download(Date.yesterday)
    }

    it 'logs a warning event' do
      @logger.logged(:warn).size.should eq 1
      @logger.logged(:warn).last.should =~ /Update not found/
    end
  end

  describe '#not_found_on_file_system logging' do
    let(:taric_update) { create :taric_update }

    before { taric_update.apply }

    it 'logs an error event' do
      @logger.logged(:error).size.should eq 1
      @logger.logged(:error).last.should =~ /Update not found on file system/
    end

    it 'sends error email' do
      ActionMailer::Base.deliveries.should_not be_empty
      email = ActionMailer::Base.deliveries.last
      email.encoded.should =~ /was not found/
    end
  end

  describe '#download_chief logging' do
    let(:success_response) { build :response, :success }

    before {
      # Download mock response
      TariffSynchronizer::ChiefUpdate.expects(:download_content).returns(success_response)
      # Do not write file to file system
      TariffSynchronizer::ChiefUpdate.expects(:create_entry).returns(true)
      # Actual Download
      TariffSynchronizer::ChiefUpdate.download(Date.today)
    }

    it 'logs an info event' do
      @logger.logged(:info).size.should eq 1
      @logger.logged(:info).last.should =~ /Downloaded CHIEF update/
    end
  end

  describe '#apply_chief logging' do
    let(:chief_update) { create :chief_update }

    before {
      # Test in isolation, file is not actually in the file system
      # so bypass the check
      File.expects(:exists?)
          .with(chief_update.file_path)
          .twice
          .returns(true)

      rescuing {
        chief_update.apply
      }
    }

    it 'logs an info event' do
      @logger.logged(:info).size.should eq 1
      @logger.logged(:info).last.should =~ /Applied CHIEF update/
    end
  end

  describe '#download_taric logging' do
    let(:success_response) { build :response, :success }

    before {
      # Skip Taric update file name fetching
      TariffSynchronizer::TaricUpdate.expects(:taric_update_urls_for).returns(['abc'])
      # Download mock response
      TariffSynchronizer::TaricUpdate.expects(:download_content).returns(success_response)
      # Do not write file to file system
      TariffSynchronizer::TaricUpdate.expects(:create_entry).returns(true)
      # Actual Download
      TariffSynchronizer::TaricUpdate.download(Date.today)
    }

    it 'logs an info event' do
      @logger.logged(:info).size.should eq 1
      @logger.logged(:info).last.should =~ /Downloaded TARIC update/
    end
  end

  describe '#apply_taric logging' do
    let(:taric_update) { create :taric_update }

    before {
      # Test in isolation, file is not actually in the file system
      # so bypass the check
      File.expects(:exists?)
          .with(taric_update.file_path)
          .twice
          .returns(true)

      rescuing {
        taric_update.apply
      }
    }

    it 'logs an info event' do
      @logger.logged(:info).size.should eq 1
      @logger.logged(:info).last.should =~ /Applied TARIC update/
    end
  end

  describe '#get_taric_update_name logging' do
    let(:not_found_response) { build :response, :not_found }

    before {
      TariffSynchronizer::TaricUpdate.expects(:download_content).returns(not_found_response)
      TariffSynchronizer::TaricUpdate.download(Date.today)
    }

    it 'logs an info event' do
      @logger.logged(:info).size.should eq 1
      @logger.logged(:info).first.should =~ /Checking for TARIC update/
    end
  end

  describe '#update_written logging' do
    let(:success_response) { build :response, :success }

    before {
      # Download mock response
      TariffSynchronizer::ChiefUpdate.expects(:download_content).returns(success_response)
      # Do not write file to file system
      TariffSynchronizer::ChiefUpdate.expects(:write_file).returns(true)
      # Actual Download
      TariffSynchronizer::ChiefUpdate.download(Date.today)
    }

    it 'logs an info event' do
      @logger.logged(:info).size.should eq 2
      @logger.logged(:info).first.should =~ /Update file written to/
    end
  end

  describe '#blank_update logging' do
    let(:blank_response) { build :response, :blank }

    before {
      # Download mock response
      TariffSynchronizer::ChiefUpdate.expects(:download_content)
                                     .returns(blank_response)
      # Actual Download
      TariffSynchronizer::ChiefUpdate.download(Date.today)
    }

    it 'logs an error event' do
      @logger.logged(:error).size.should eq 1
      @logger.logged(:error).first.should =~ /Blank update content/
    end

    it 'sends and error email' do
      ActionMailer::Base.deliveries.should_not be_empty
      email = ActionMailer::Base.deliveries.last
      email.encoded.should =~ /blank file/
    end
  end

  describe '#cant_open_file logging' do
    let(:success_response) { build :response, :success }

    before {
      # Download mock response
      TariffSynchronizer::ChiefUpdate.expects(:download_content)
                                     .returns(success_response)
      # Simulate I/O exception
      File.expects(:open).raises(Errno::ENOENT)
      # Actual Download
      TariffSynchronizer::ChiefUpdate.download(Date.today)
    }

    it 'logs an error event' do
      @logger.logged(:error).size.should eq 1
      @logger.logged(:error).first.should =~ /for writing/
    end

    it 'sends and error email' do
      ActionMailer::Base.deliveries.should_not be_empty
      email = ActionMailer::Base.deliveries.last
      email.encoded.should =~ /open for writing/
    end
  end

  describe '#cant_write_to_file logging' do
    let(:success_response) { build :response, :success }

    before {
      # Download mock response
      TariffSynchronizer::ChiefUpdate.expects(:download_content)
                                     .returns(success_response)
      # Simulate I/O exception
      File.expects(:open).raises(IOError)
      # Actual Download
      TariffSynchronizer::ChiefUpdate.download(Date.today)
    }

    it 'logs an error event' do
      @logger.logged(:error).size.should eq 1
      @logger.logged(:error).first.should =~ /write to update file/
    end

    it 'sends and error email' do
      ActionMailer::Base.deliveries.should_not be_empty
      email = ActionMailer::Base.deliveries.last
      email.encoded.should =~ /write to file/
    end
  end

  describe '#write_permission_error logging' do
    let(:success_response) { build :response, :success }

    before {
      # Download mock response
      TariffSynchronizer::ChiefUpdate.expects(:download_content)
                                     .returns(success_response)
      # Simulate I/O exception
      File.expects(:open).raises(Errno::EACCES)
      # Actual Download
      TariffSynchronizer::ChiefUpdate.download(Date.today)
    }

    it 'logs an error event' do
      @logger.logged(:error).size.should eq 1
      @logger.logged(:error).first.should =~ /No permission/
    end

    it 'sends and error email' do
      ActionMailer::Base.deliveries.should_not be_empty
      email = ActionMailer::Base.deliveries.last
      email.encoded.should =~ /permission error/
    end
  end

  describe '#delay_download logging' do
    let(:failed_response)  { build :response, :failed }
    let(:success_response) { build :response, :success }

    before {
      TariffSynchronizer.retry_count = 10
      TariffSynchronizer::ChiefUpdate.expects(:send_request)
                                     .twice
                                     .returns(failed_response)
                                     .then
                                     .returns(success_response)
      TariffSynchronizer::ChiefUpdate.download(Date.today)
    }

    it 'logs an info event' do
      @logger.logged(:info).size.should be >= 1
      @logger.logged(:info).to_s.should =~ /Delaying update fetching/
    end
  end

  describe '#missing_updates' do
    let(:not_found_response) { build :response, :not_found }
    let!(:chief_update1) { create :chief_update, :missing, issue_date: Date.today.ago(2.days) }
    let!(:chief_update2) { create :chief_update, :missing, issue_date: Date.today.ago(3.days) }

    before {
      TariffSynchronizer::ChiefUpdate.stubs(:download_content)
                                     .returns(not_found_response)
      TariffSynchronizer::ChiefUpdate.sync
    }

    it 'logs a warn event' do
      @logger.logged(:warn).size.should be > 1
      @logger.logged(:warn).to_s.should =~ /Missing/
    end

    it 'sends a warning email' do
      ActionMailer::Base.deliveries.should_not be_empty
      email = ActionMailer::Base.deliveries.last
      email.encoded.should =~ /missing/
    end
  end

  describe "#invalidated" do
    let(:measure) { create :measure }

    before {
      ChiefTransformer::Processor::Operation.new(nil)
      .update_record(measure, validity_start_date: Date.today.in(10.years),
                              validity_end_date: Date.today.ago(10.years))
    }

    it 'logs a warn event' do
      @logger.logged(:warn).size.should eq 1
      @logger.logged(:warn).to_s.should =~ /Invalid/
    end
  end
end
