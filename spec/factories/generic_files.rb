FactoryGirl.define do
  factory :generic_file do
    fileable_type { 'EmployeeFile' }

    trait :with_jpg do
      file File.open(File.join(Rails.root, '/spec/fixtures/files/test.jpg'))
    end

    trait :with_pdf do
      file File.open(File.join(Rails.root, '/spec/fixtures/files/example.pdf'))
    end

    trait :with_doc do
      file File.open(File.join(Rails.root, '/spec/fixtures/files/sample.doc'))
    end

    trait :with_docx do
      file File.open(File.join(Rails.root, '/spec/fixtures/files/test.docx'))
    end

    trait :with_zip do
      file File.open(File.join(Rails.root, '/spec/fixtures/files/test.zip'))
    end

    trait :without_file do
      file nil
    end
  end
end
