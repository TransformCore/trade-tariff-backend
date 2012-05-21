require 'spec_helper'

describe Commodity do
  # fields
  it { should have_fields(:code, :description, :hier_pos, :substring) }

  # associations
  it { should belong_to :nomenclature }
  it { should belong_to :heading }
end