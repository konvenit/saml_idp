require 'spec_helper'
module SamlIdp
  describe ServiceProvider do
    subject { described_class.new attributes }
    let(:attributes) { {} }

    it { should respond_to :fingerprint }
    it { should respond_to :metadata_url }
    it { should_not be_valid }

    describe "with attributes" do
      let(:attributes) { { fingerprint: fingerprint, metadata_url: metadata_url } }
      let(:fingerprint) { Default::FINGERPRINT }
      let(:metadata_url) { "http://localhost:3000/metadata" }

      it "has a valid fingerprint" do
        expect(subject.fingerprint).to eq(fingerprint)
      end

      it "has a valid metadata_url" do
        expect(subject.metadata_url).to eq(metadata_url)
      end

      it { should be_valid }
    end

    describe "#current_metadata" do
      before do
        SamlIdp.config.service_provider.persisted_metadata_getter = persisted_metadata_getter
        SamlIdp.config.service_provider.metadata_persister = metadata_persister
      end

      let(:persisted_metadata_getter) { ->(identifier, service_provider) { @persisted_metadata } }
      let(:metadata_persister) { ->(identifier, incoming_metadata) { @persisted_metadata = incoming_metadata.to_h } }

      context "when metadata has been persisted" do
        before { @persisted_metadata = { "hello" => "world" } }

        it "returns persisted metadata" do
          expect(metadata_persister).to_not receive(:[])

          metadata = subject.current_metadata
          expect(metadata).to be_a(SamlIdp::PersistedMetadata)
          expect(metadata.attributes).to eq({ "hello" => "world" })
        end
      end

      context "when metadata has not yet been persisted" do
        it "downloads and persists metadata" do
          expect(subject).to receive(:request_metadata).and_return(<<-XML)
            <md:EntityDescriptor xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata" xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion" ID="test" entityID="https://test-saml.com/saml">
              <md:SPSSODescriptor protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol" AuthnRequestsSigned="true" WantAssertionsSigned="true">
              </md:SPSSODescriptor>
            </md:EntityDescriptor>
          XML
          expect(metadata_persister).to receive(:[]).with(anything, instance_of(IncomingMetadata))

          metadata = subject.current_metadata
          expect(metadata).to be_a(SamlIdp::PersistedMetadata)
          expect(metadata.sign_assertions?).to eq(true) # check against an attribute from received XML
        end
      end
    end
  end
end
