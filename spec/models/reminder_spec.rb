require 'spec_helper'

RSpec.describe Reminder do
  describe '.parse_days' do
    subject(:result) { described_class.parse_days(input) }

    context 'with "все"' do
      let(:input) { 'все' }
      it { is_expected.to eq(Reminder::ALL_DAYS) }
    end

    context 'with "будни"' do
      let(:input) { 'будни' }
      it { is_expected.to eq(%w[mon tue wed thu fri]) }
    end

    context 'with "выходные"' do
      let(:input) { 'выходные' }
      it { is_expected.to eq(%w[sat sun]) }
    end

    context 'with a comma-separated list of valid abbreviations' do
      let(:input) { 'mon,wed,fri' }
      it { is_expected.to eq(%w[mon wed fri]) }
    end

    context 'with spaces around abbreviations' do
      let(:input) { 'mon, wed, fri' }
      it { is_expected.to eq(%w[mon wed fri]) }
    end

    context 'with uppercase abbreviations' do
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

    context 'with a single valid abbreviation' do
      let(:input) { 'tue' }
      it { is_expected.to eq(%w[tue]) }
    end
  end
end
