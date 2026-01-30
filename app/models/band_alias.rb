# frozen_string_literal: true

class BandAlias < ApplicationRecord
  belongs_to :band

  validates :name, presence: true

  scope :search_by_name, ->(query) {
    where("name % ?", query)
      .order(Arel.sql("similarity(name, #{connection.quote(query)}) DESC"))
  }
end
