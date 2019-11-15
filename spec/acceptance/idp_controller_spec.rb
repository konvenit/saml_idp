require File.expand_path(File.dirname(__FILE__) + '/acceptance_helper')

feature 'IdpController' do
  let(:saml_request) { make_saml_request("http://foo.example.com/saml/consume") }

  shared_examples 'Login via default signup page' do
    scenario 'Users are sent back to the Service Provider after signing in' do
      expect(status_code).to eq(200)

      fill_in 'email', :with => "foo@example.com"
      fill_in 'password', :with => "okidoki"
      click_button 'Sign in'
      expect(page).to_not have_field('email')
      expect(page).to_not have_field('password')
      expect(find('body')['onload']).to eq('document.forms[0].submit();')

      click_button 'Submit' # simulating onload
      expect(current_url).to eq('http://foo.example.com/saml/consume')
      expect(page).to have_content "foo@example.com"
    end
  end

  context 'HTTP-Redirect' do
    before { visit "/saml/auth?SAMLRequest=#{CGI.escape(saml_request)}" }
    it_behaves_like 'Login via default signup page'
  end

  context 'HTTP-POST' do
    before { page.driver.post "/saml/auth", SAMLRequest: saml_request }
    it_behaves_like 'Login via default signup page'
  end
end
