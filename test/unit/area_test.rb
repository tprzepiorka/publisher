require 'test_helper'
require 'gds_api/test_helpers/imminence'
require 'imminence_areas_test_helper'

class AreaTest < ActiveSupport::TestCase

  include GdsApi::TestHelpers::Imminence
  include ImminenceAreasTestHelper

  setup do
    stub_mapit_areas_requests(IMMINENCE_API_ENDPOINT)
  end

  def test_api_data_memoization
    Area.class_eval('@areas = nil')

    3.times { Area.all }

    assert_requested :get, %r{\A#{IMMINENCE_API_ENDPOINT}/areas/EUR.json}, times: 1
    assert_requested :get, %r{\A#{IMMINENCE_API_ENDPOINT}/areas/CTY.json}, times: 1
    assert_requested :get, %r{\A#{IMMINENCE_API_ENDPOINT}/areas/DIS.json}, times: 1
    assert_requested :get, %r{\A#{IMMINENCE_API_ENDPOINT}/areas/LBO.json}, times: 1
    assert_requested :get, %r{\A#{IMMINENCE_API_ENDPOINT}/areas/LGD.json}, times: 1
    assert_requested :get, %r{\A#{IMMINENCE_API_ENDPOINT}/areas/MTD.json}, times: 1
    assert_requested :get, %r{\A#{IMMINENCE_API_ENDPOINT}/areas/UTA.json}, times: 1
  end

  def test_area_types
    assert_equal ['EUR','CTY','DIS','LBO', 'LGD', 'MTD', 'UTA'], Area::AREA_TYPES
  end

  def test_all
    assert_equal regions + counties + districts + london_boroughs + ni_councils + 
      metropolitan_councils + unitary_authorities, Area.all.map(&:marshal_dump)
  end

  def test_areas_for_edition
    edition = OpenStruct.new(areas: ["london", "hackney-borough-council"])
    assert_equal ["London", "Hackney Borough Council"], Area.areas_for_edition(edition).map(&:name)
  end

  def test_regions
    assert_equal ["London", "Scotland"], Area.regions.map(&:name)
  end

  def test_english_regions
    assert_equal ["London"], Area.english_regions.map(&:name)
  end
end
