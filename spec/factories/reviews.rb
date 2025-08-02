FactoryBot.define do
  factory :review do
    song_link { "MyString" }
    band_name { "MyString" }
    song_name { "MyString" }
    artwork_url { "MyString" }
    band { nil }
    user { nil }
    review_text { "MyText" }
    overall_rating { 1 }
    liked_aspects { "MyText" }
  end
end
