require 'spec_helper'

RSpec.describe Reminder do
  describe '.parse_days' do
    subject(:result) { described_class.parse_days(input) }

    context 'with "all"' do
      let(:input) { 'all' }
      it { is_expected.to eq(Reminder::ALL_DAYS) }
    end

    context 'with "weekdays"' do
      let(:input) { 'weekdays' }
      it { is_expected.to eq(%w[mon tue wed thu fri]) }
    end

    context 'with "weekend"' do
      let(:input) { 'weekend' }
      it { is_expected.to eq(%w[sat sun]) }
    end

    context 'with a comma-separated list of valid days' do
      let(:input) { 'mon,wed,fri' }
      it { is_expected.to eq(%w[mon wed fri]) }
    end

    context 'with spaces around day abbreviations' do
      let(:input) { 'mon, wed, fri' }
      it { is_expected.to eq(%w[mon wed fri]) }
    end

    context 'with uppercase input' do
      let(:input) { 'MON,WED' }
      it { is_expected.to eq(%w[mon wed]) }
    end

    context 'with a mix of valid and invalid abbreviations' do
      let(:input) { 'mon,xyz,fri' }
      it { is_expected.to eq(%w[mon fri]) }
    end

    context 'with only invalid abbreviations' do
      let(:input) { 'xyz,abc' }
      it { is_expected.to be_empty }
    end

    context 'with a single valid day' do
      let(:input) { 'tue' }
      it { is_expected.to eq(%w[tue]) }
    end
  end
end
