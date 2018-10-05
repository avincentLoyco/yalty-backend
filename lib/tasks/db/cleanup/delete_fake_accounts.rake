namespace :db do
  namespace :cleanup do
    require "account_removal"

    desc "Delete fake and test accounts"
    task delete_fake_accounts: [:environment] do

      # NOTE: Below accounts were recognised as fake or test ones
      # on production DB.
      account_subdomains = %w(
        alexis-test
        antistatiquetest
        applepie-test
        applepie-test-166
        demco-782
        demo
        demo1
        demo2
        demo234
        example-acc
        example-company
        exemple-2
        exemple1
        exemple3
        exemplex
        gacek-wy-company
        jakataka
        jakataka3
        janmonte
        jobtest
        jojocorp
        loyco
        loyco-136
        loyco-177
        loytest
        madlenowa
        magdamagda
        moja-nowa
        moja-nowa-subdomena
        mon
        montemonte
        monterail
        monterail-370
        monterail-994
        monterail-test
        montetest
        montetest1
        my-company
        my-company-115
        nadine-entreprise-test
        new2
        olenab
        polyrighttest
        polyrighttest-669
        referrer-test
        roman-test
        test
        test-281
        test-418
        test-586
        test-598
        test-65
        test-672
        test-730
        test-886
        test-914
        test-946
        test-955
        test-a-ems
        test-ag
        test-app
        test-pineapple
        test1
        test123
        test2
        test3
        testaccount
        testbartek
        testbartek2
        testbartek3
        testdg
        testfactory
        testing
        testmagda
        testmagda-269
        testminnich
        testminnich-two
        testnadine
        testsession
        testsession-179
        verylongcompanyname
        yalty-194
        z-test-z-test
      )

      account_subdomains.each do |subdomain|
        begin
          AccountRemoval.new(subdomain).call
        rescue StandardError => e
          Rails.logger.debug "#{subdomain}: #{e.message}"
        end
      end
    end
  end
end
