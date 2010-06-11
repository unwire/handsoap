require 'rubygems'
require 'test/unit'

$LOAD_PATH << "#{File.dirname(__FILE__)}/../lib/"
require "handsoap"
require 'handsoap/xml_query_front'

module AbstractXmlDriverTestCase
  def xml_source
    '<?xml version="1.0"?>
<SOAP-ENV:Envelope
xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
 <SOAP-ENV:Body>
  <encoding-test>' + "bl\303\245b\303\246rgr\303\270d" + '</encoding-test>
  <cdata-test><![CDATA[character data]]></cdata-test>
  <entity-test>bl&#x00e5;b&#x00E6;rgr&#x00F8;d</entity-test>
  <m:ThumbnailResponse
xmlns:m="http://ast.amazonaws.com/doc/2006-05-15/">
   <aws:Response
xmlns:aws="http://ast.amazonaws.com/doc/2006-05-15/">
    <aws:OperationRequest>
     <aws:RequestId>3f8ceabd-2d15-47f0-b35e-d52ee868a4a6</aws:RequestId>
    </aws:OperationRequest>
    <aws:ThumbnailResult>
     <aws:Thumbnail
Exists="true" attr-test="bl&#x00e5;b&#x00E6;rgr&#x00F8;d" foo="foobar">http://location_to_thumbnail_for_www.alexa.com</aws:Thumbnail>
     <aws:RequestUrl>www.alexa.com</aws:RequestUrl>
    </aws:ThumbnailResult>
    <m:ResponseStatus>
     <m:StatusCode>Success</m:StatusCode>
    </m:ResponseStatus>
   </aws:Response>
   <aws:Response
xmlns:aws="http://ast.amazonaws.com/doc/2006-05-15/">
    <aws:OperationRequest>
     <aws:RequestId>3f8ceabd-2d15-47f0-b35e-d52ee868a4a6</aws:RequestId>
    </aws:OperationRequest>
    <aws:ThumbnailResult>
     <aws:Thumbnail
Exists="true">http://location_to_thumbnail_for_www.amazon.com</aws:Thumbnail>
     <aws:RequestUrl>www.amazon.com</aws:RequestUrl>
    </aws:ThumbnailResult>
    <m:ResponseStatus>
     <m:StatusCode>Success</m:StatusCode>
    </m:ResponseStatus>
   </aws:Response>
   <aws:Response
xmlns:aws="http://ast.amazonaws.com/doc/2006-05-15/">
    <aws:OperationRequest>
     <aws:RequestId>3f8ceabd-2d15-47f0-b35e-d52ee868a4a6</aws:RequestId>
    </aws:OperationRequest>
    <aws:ThumbnailResult>
     <aws:Thumbnail
Exists="true">http://location_to_thumbnail_for_www.a9.com</aws:Thumbnail>
     <aws:RequestUrl>www.a9.com</aws:RequestUrl>
    </aws:ThumbnailResult>
    <m:ResponseStatus>
     <m:StatusCode>Success</m:StatusCode>
    </m:ResponseStatus>
   </aws:Response>
  </m:ThumbnailResponse>
 </SOAP-ENV:Body>
</SOAP-ENV:Envelope>'
  end
  def create_default_document
    doc = Handsoap::XmlQueryFront.parse_string(xml_source, driver)
    doc.add_namespace("foo", "http://ast.amazonaws.com/doc/2006-05-15/")
    doc.add_namespace("aws", "http://ast.amazonaws.com/doc/2006-05-15/")
    doc
  end
  def test_query_for_undefined_prefix_raises
    doc = Handsoap::XmlQueryFront.parse_string(xml_source, driver)
    assert_raise RuntimeError do
      doc.xpath("//aws:OperationRequest")
    end
  end
  def test_axis_isnt_interpreted_as_a_namespace
    doc = Handsoap::XmlQueryFront.parse_string(xml_source, driver)
    doc.xpath('/env:Envelope/env:Body/descendant-or-self::env:Fault', { 'env' => "void://" })
  end
  def test_query_for_defined_prefix
    doc = Handsoap::XmlQueryFront.parse_string(xml_source, driver)
    doc.add_namespace("aws", "http://ast.amazonaws.com/doc/2006-05-15/")
    doc.xpath("//aws:OperationRequest")
  end
  def test_get_node_name
    doc = create_default_document
    assert_equal "Thumbnail", doc.xpath("//aws:Response/aws:ThumbnailResult/*").first.node_name
  end
  def test_get_node_namespace
    doc = create_default_document
    assert_equal "http://ast.amazonaws.com/doc/2006-05-15/", doc.xpath("//aws:Response/aws:ThumbnailResult/*").first.node_namespace
  end
  def test_get_nil_node_namespace
    doc = create_default_document
    assert_equal nil, doc.xpath("//entity-test").first.node_namespace
  end
  def test_get_attribute_name
    doc = create_default_document
    assert_equal "Exists", doc.xpath("//aws:Thumbnail/@Exists").first.node_name
  end
  def test_get_text_selection_as_string
    doc = create_default_document
    assert_equal "http://location_to_thumbnail_for_www.alexa.com", doc.xpath("//aws:Thumbnail[1]/text()").to_s
  end
  def test_query_with_multiple_prefixes_for_same_namespace
    doc = create_default_document
    assert_equal "3f8ceabd-2d15-47f0-b35e-d52ee868a4a6", doc.xpath("//foo:OperationRequest/aws:RequestId").first.to_s
  end
  def test_hpricot_style_searching_is_supported
    doc = create_default_document
    assert_equal "3f8ceabd-2d15-47f0-b35e-d52ee868a4a6", (doc/"//foo:OperationRequest/aws:RequestId").first.to_s
  end
  def test_query_result_is_mappable
    doc = create_default_document
    assert_equal "3f8ceabd-2d15-47f0-b35e-d52ee868a4a6\n3f8ceabd-2d15-47f0-b35e-d52ee868a4a6\n3f8ceabd-2d15-47f0-b35e-d52ee868a4a6", doc.xpath("//foo:OperationRequest/aws:RequestId").map{|e| e.to_s }.join("\n")
  end
  def test_resultset_inherits_prefixes
    doc = create_default_document
    assert_equal "3f8ceabd-2d15-47f0-b35e-d52ee868a4a6", doc.xpath("//foo:OperationRequest").first.xpath("aws:RequestId").first.to_s
  end
	def test_resultset_delegates_slash
    doc = create_default_document
    operation_request = (doc/"//foo:OperationRequest")
    assert_equal "3f8ceabd-2d15-47f0-b35e-d52ee868a4a6", (operation_request/"aws:RequestId").to_s
  end
  def test_attribute_can_cast_to_boolean
    doc = create_default_document
    assert_kind_of TrueClass, doc.xpath("//aws:Thumbnail/@Exists").first.to_boolean
  end
  def test_text_content_is_utf8
    doc = create_default_document
    assert_equal "bl\303\245b\303\246rgr\303\270d", doc.xpath("//encoding-test").first.to_s
  end
  def test_cdata_has_no_surrounding_markers
    doc = create_default_document
    assert_equal "character data", doc.xpath("//cdata-test").first.to_s
  end
  def test_entity_escaped_text_content_is_utf8
    doc = create_default_document
    assert_equal "bl\303\245b\303\246rgr\303\270d", doc.xpath("//entity-test").first.to_s
  end
  def test_entity_escaped_attribute_is_utf8
    doc = create_default_document
    assert_equal "bl\303\245b\303\246rgr\303\270d", doc.xpath("//aws:Thumbnail/@attr-test").first.to_s
  end
  def test_error_on_parsing_non_xml
    assert_raise Handsoap::XmlQueryFront::ParseError do
      doc = Handsoap::XmlQueryFront.parse_string("blah", driver)
    end
  end
  def test_error_on_parsing_empty_string
    assert_raise Handsoap::XmlQueryFront::ParseError do
      doc = Handsoap::XmlQueryFront.parse_string("", driver)
    end
  end
  def test_error_on_parsing_empty_document
    assert_raise Handsoap::XmlQueryFront::ParseError do
      doc = Handsoap::XmlQueryFront.parse_string("<?xml version='1.0' ?>", driver)
    end
  end
  def test_serialize_pretty
    doc = Handsoap::XmlQueryFront.parse_string('<?xml version="1.0" encoding="UTF-8"?><foo><bar>blah</bar></foo>', driver)
    assert_equal "<foo>\n  <bar>blah</bar>\n</foo>", doc.xpath("//foo").to_xml
  end
  def test_serialize_raw
    str = "<foo>\n\t\t<bar>blah\n</bar>\n</foo>"
    doc = Handsoap::XmlQueryFront.parse_string("<?xml version='1.0' encoding='UTF-8'?>" + str, driver)
    assert_equal str, doc.xpath("//foo").to_raw
  end
  def test_an_unformatted_string_can_be_serialized_raw
    doc = Handsoap::XmlQueryFront.parse_string('<?xml version="1.0" encoding="UTF-8"?><foo><bar>blah</bar></foo>', driver)
    assert_equal "<foo><bar>blah</bar></foo>", doc.xpath("//foo").to_raw
  end
  def test_query_by_syntactic_sugar
    doc = create_default_document
    assert_equal 3, (doc/"//aws:OperationRequest[1]/aws:RequestId").to_i
    assert_equal (doc/"//aws:OperationRequest[1]/aws:RequestId").to_i, (doc/"//aws:OperationRequest[1]/aws:RequestId").first.to_i
  end
  def test_attribute_hash_access
    doc = create_default_document
    node = doc.xpath("//aws:Thumbnail").first
    assert_equal "bl\303\245b\303\246rgr\303\270d", node['attr-test']
  end
  def test_attribute_hash_access_fails_with_a_symbol
    doc = create_default_document
    node = doc.xpath("//aws:Thumbnail").first
    assert_raise ArgumentError do
      assert_equal "foobar", node[:foo]
    end
  end
  def test_select_children
    doc = create_default_document
    node = doc.xpath("//aws:ThumbnailResponse").first
    result = node.children.map { |node| node.node_name }.join(",")
    assert_equal "text,Response,text,Response,text,Response,text", result
  end
end

class TestOfREXMLDriver < Test::Unit::TestCase
  include AbstractXmlDriverTestCase
  def driver
    :rexml
  end
end

class TestOfNokogiriDriver < Test::Unit::TestCase
  include AbstractXmlDriverTestCase
  def driver
    :nokogiri
  end
end

class TestOfLibXMLDriver < Test::Unit::TestCase
  include AbstractXmlDriverTestCase
  def driver
    :libxml
  end
end
