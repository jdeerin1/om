require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require "om"

describe "OM::XML::TemplateRegistry" do

  before(:all) do
    class RegistryTest

      include OM::XML::Document

      set_terminology do |t|
        t.root(:path => "people", :xmlns => 'urn:registry-test')
        t.person {
          t.title(:path => "@title")
        }
      end

      define_template :person do |xml,name,title|
        xml.person(:title => title) do
          xml.text(name)
        end
      end

    end
  end
  
  after(:all) do
    Object.send(:remove_const, :RegistryTest)
  end

  before(:each) do
    @test_document = RegistryTest.from_xml('<people xmlns="urn:registry-test"><person title="Actor">Alice</person></people>')
    @expectations = {
      :before  => %{<people xmlns="urn:registry-test"><person title="Builder">Bob</person><person title="Actor">Alice</person></people>},
      :after   => %{<people xmlns="urn:registry-test"><person title="Actor">Alice</person><person title="Builder">Bob</person></people>},
      :instead => %{<people xmlns="urn:registry-test"><person title="Builder">Bob</person></people>}
    }
  end
  
  describe "template definitions" do
    it "should contain predefined templates" do
      RegistryTest.template_registry.node_types.should include(:person)
      RegistryTest.template_registry.node_types.should_not include(:zombie)
    end

    it "should define new templates" do
      RegistryTest.template_registry.node_types.should_not include(:zombie)
      RegistryTest.define_template :zombie do |xml,name|
        xml.monster(:wants => 'braaaaainz') do
          xml.text(name)
        end
      end
      RegistryTest.template_registry.node_types.should include(:zombie)
    end

    it "should instantiate a detached node from a template" do
      node = RegistryTest.template_registry.instantiate(:zombie, 'Zeke')
      expectation = Nokogiri::XML('<monster wants="braaaaainz">Zeke</monster>').root
      node.should be_equivalent_to(expectation)
    end
    
    it "should raise an error when trying to instantiate an unknown node_type" do
      lambda { RegistryTest.template_registry.instantiate(:demigod, 'Hercules') }.should raise_error(NameError)
    end
    
    it "should instantiate a detached node from a template using the template name as a method" do
      node = RegistryTest.template_registry.zombie('Zeke')
      expectation = Nokogiri::XML('<monster wants="braaaaainz">Zeke</monster>').root
      node.should be_equivalent_to(expectation)
    end
    
    it "should raise an exception if a missing method name doesn't match a node_type" do
      lambda { RegistryTest.template_registry.demigod('Hercules') }.should raise_error(NameError)
    end
    
    it "should undefine existing templates" do
      RegistryTest.template_registry.node_types.should include(:zombie)
      RegistryTest.template_registry.undefine :zombie
      RegistryTest.template_registry.node_types.should_not include(:zombie)
    end
    
    it "should complain if the template name isn't a symbol" do
      lambda { RegistryTest.template_registry.define("die!") { |xml| xml.this_never_happened } }.should raise_error(TypeError)
    end
    
    it "should report on whether a given template is defined" do
      RegistryTest.template_registry.has_node_type?(:person).should == true
      RegistryTest.template_registry.has_node_type?(:zombie).should == false
    end
    
    it "should include defined node_types as method names for introspection" do
      RegistryTest.template_registry.methods.should include('person')
    end
  end
  
  describe "template-based document manipulations" do
    it "should accept a Nokogiri::XML::Node as target" do
      @test_document.template_registry.after(@test_document.ng_xml.root.elements.first, :person, 'Bob', 'Builder')
      @test_document.ng_xml.root.elements.length.should == 2
    end

    it "should accept a Nokogiri::XML::NodeSet as target" do
      @test_document.template_registry.after(@test_document.find_by_terms(:person => 0), :person, 'Bob', 'Builder')
      @test_document.ng_xml.root.elements.length.should == 2
    end
    
    it "should add_child" do
      return_value = @test_document.template_registry.add_child(@test_document.ng_xml.root, :person, 'Bob', 'Builder')
      return_value.should == @test_document.find_by_terms(:person => 1).first
      @test_document.ng_xml.should be_equivalent_to(@expectations[:after]).respecting_element_order
    end
    
    it "should add_next_sibling" do
      return_value = @test_document.template_registry.add_next_sibling(@test_document.find_by_terms(:person => 0), :person, 'Bob', 'Builder')
      return_value.should == @test_document.find_by_terms(:person => 1).first
      @test_document.ng_xml.should be_equivalent_to(@expectations[:after]).respecting_element_order
    end

    it "should add_previous_sibling" do
      return_value = @test_document.template_registry.add_previous_sibling(@test_document.find_by_terms(:person => 0), :person, 'Bob', 'Builder')
      return_value.should == @test_document.find_by_terms(:person => 0).first
      @test_document.ng_xml.should be_equivalent_to(@expectations[:before]).respecting_element_order
    end

    it "should after" do
      return_value = @test_document.template_registry.after(@test_document.find_by_terms(:person => 0), :person, 'Bob', 'Builder')
      return_value.should == @test_document.find_by_terms(:person => 0).first
      @test_document.ng_xml.should be_equivalent_to(@expectations[:after]).respecting_element_order
    end

    it "should before" do
      return_value = @test_document.template_registry.before(@test_document.find_by_terms(:person => 0), :person, 'Bob', 'Builder')
      return_value.should == @test_document.find_by_terms(:person => 1).first
      @test_document.ng_xml.should be_equivalent_to(@expectations[:before]).respecting_element_order
    end

    it "should replace" do
      target_node = @test_document.find_by_terms(:person => 0).first
      return_value = @test_document.template_registry.replace(target_node, :person, 'Bob', 'Builder')
      return_value.should == @test_document.find_by_terms(:person => 0).first
      @test_document.ng_xml.should be_equivalent_to(@expectations[:instead]).respecting_element_order
    end

    it "should swap" do
      target_node = @test_document.find_by_terms(:person => 0).first
      return_value = @test_document.template_registry.swap(target_node, :person, 'Bob', 'Builder')
      return_value.should == target_node
      @test_document.ng_xml.should be_equivalent_to(@expectations[:instead]).respecting_element_order
    end
  end
    
  describe "document-based document manipulations" do
    it "should accept a Nokogiri::XML::Node as target" do
      @test_document.after_node(@test_document.ng_xml.root.elements.first, :person, 'Bob', 'Builder')
      @test_document.ng_xml.root.elements.length.should == 2
    end

    it "should accept a Nokogiri::XML::NodeSet as target" do
      @test_document.after_node(@test_document.find_by_terms(:person => 0), :person, 'Bob', 'Builder')
      @test_document.ng_xml.root.elements.length.should == 2
    end
    
    it "should accept a term-pointer array as target" do
      @test_document.after_node([:person => 0], :person, 'Bob', 'Builder')
      @test_document.ng_xml.root.elements.length.should == 2
    end
    
    it "should add_child_node" do
      return_value = @test_document.add_child_node(@test_document.ng_xml.root, :person, 'Bob', 'Builder')
      return_value.should == @test_document.find_by_terms(:person => 1).first
      @test_document.ng_xml.should be_equivalent_to(@expectations[:after]).respecting_element_order
    end
    
    it "should add_next_sibling_node" do
      return_value = @test_document.add_next_sibling_node([:person => 0], :person, 'Bob', 'Builder')
      return_value.should == @test_document.find_by_terms(:person => 1).first
      @test_document.ng_xml.should be_equivalent_to(@expectations[:after]).respecting_element_order
    end

    it "should add_previous_sibling_node" do
      return_value = @test_document.add_previous_sibling_node([:person => 0], :person, 'Bob', 'Builder')
      return_value.should == @test_document.find_by_terms(:person => 0).first
      @test_document.ng_xml.should be_equivalent_to(@expectations[:before]).respecting_element_order
    end

    it "should after_node" do
      return_value = @test_document.after_node([:person => 0], :person, 'Bob', 'Builder')
      return_value.should == @test_document.find_by_terms(:person => 0).first
      @test_document.ng_xml.should be_equivalent_to(@expectations[:after]).respecting_element_order
    end

    it "should before_node" do
      return_value = @test_document.before_node([:person => 0], :person, 'Bob', 'Builder')
      return_value.should == @test_document.find_by_terms(:person => 1).first
      @test_document.ng_xml.should be_equivalent_to(@expectations[:before]).respecting_element_order
    end

    it "should replace_node" do
      target_node = @test_document.find_by_terms(:person => 0).first
      return_value = @test_document.replace_node(target_node, :person, 'Bob', 'Builder')
      return_value.should == @test_document.find_by_terms(:person => 0).first
      @test_document.ng_xml.should be_equivalent_to(@expectations[:instead]).respecting_element_order
    end

    it "should swap_node" do
      target_node = @test_document.find_by_terms(:person => 0).first
      return_value = @test_document.swap_node(target_node, :person, 'Bob', 'Builder')
      return_value.should == target_node
      @test_document.ng_xml.should be_equivalent_to(@expectations[:instead]).respecting_element_order
    end
  end
  
end
