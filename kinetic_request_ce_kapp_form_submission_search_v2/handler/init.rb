# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class KineticRequestCeKappFormSubmissionSearchV2
  # Prepare for execution by building Hash objects for necessary values and
  # validating the present state.  This method sets the following instance
  # variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @info_values - A Hash of info names to info values.
  # * @parameters - A Hash of parameter names to parameter values.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Parameters
  # * +input+ - The String of Xml that was built by evaluating the node.xml
  #   handler template.
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)
    
    # Retrieve all of the handler info values and store them in a hash variable named @info_values.
    @info_values = {}
    REXML::XPath.each(@input_document, "/handler/infos/info") do |item|
      @info_values[item.attributes["name"]] = item.text.to_s.strip
    end

    # Retrieve all of the handler parameters and store them in a hash variable named @parameters.
    @parameters = {}
    REXML::XPath.each(@input_document, "/handler/parameters/parameter") do |item|
      @parameters[item.attributes["name"]] = item.text.to_s.strip
    end

    @formatter = REXML::Formatters::Pretty.new
    @formatter.compact = true

    @enable_debug_logging = @info_values['enable_debug_logging'] == 'Yes'
  end

  # The execute method gets called by the task engine when the handler's node is processed. It is
  # responsible for performing whatever action the name indicates.
  # If it returns a result, it will be in a special XML format that the task engine expects. These
  # results will then be available to subsequent tasks in the process.
  def execute
    raise "A space slug is required to be passed in either the Info Values or Parameters" if @parameters["space_slug"].empty? && @info_values["space_slug"].empty?

    api_username  = URI.encode(@info_values["api_username"])
    api_password  = @info_values["api_password"]
    api_server    = @info_values["api_server"]
    kapp_slug     = @parameters["kapp_slug"]
    form_slug     = @parameters["form_slug"]
    query         = @parameters["query"]
    space_slug    = @parameters["space_slug"].empty? ? @info_values["space_slug"] : @parameters["space_slug"]

    api_route = "#{api_server}/#{space_slug}/app/api/v1/kapps/#{kapp_slug}/forms/#{form_slug}/submissions?"
    api_route += "q=#{URI.escape(query)}" if !query.empty?

    puts "API ROUTE: #{api_route}"

    resource = RestClient::Resource.new(api_route, { :user => api_username, :password => api_password })

    response = resource.get

    if response.nil?
      <<-RESULTS
      <results>
        <result name="count"></result>
        <result name="result"></result>
      </results>
      RESULTS
    else
      response_json = JSON.parse(response)["submissions"]
      puts "RESULTS: #{response_json.inspect}"
      count = response_json.count

      if @parameters["return_type"] == "JSON"
        "<results><result name='count'>#{escape(count)}</result><result name='result'>#{escape(response_json.to_json)}</result></results>"
      elsif @parameters["return_type"] == "XML"
        xml = convert_json_to_xml(response_json.to_json)
        string = @formatter.write(xml, "")
        "<results><result name='count'>#{count}</result><result name='result'>#{escape(string)}</result></results>"
      else
        id_list = response_json.inject("<ids>") { |str, result| str << "<id>" + result["id"] + "</id>"; str } + "</ids>"
        "<results><result name='count'>#{count}</result><result name='result'>#{escape(id_list)}</result></results>"
      end
    end

    rescue RestClient::Exception => error
      raise StandardError, error.inspect
  end


  # This method converts a Ruby JSON Hash to a REXML::Element object.  The REXML::Element
  # that is returned is the root node of the XML structure and all of the resulting
  # XML data will be nested within that single element.
  def convert_json_to_xml(data, label=nil)
    if data.is_a?(Hash)
      element = REXML::Element.new("node")
      element.add_attribute("type", "Object")
      element.add_attribute("name", label) if label
      data.keys.each do |key|
        element.add_element(convert_json_to_xml(data[key], key))
      end
      element
    elsif data.is_a?(Array)
      element = REXML::Element.new("node")
      element.add_attribute("type", "Array")
      element.add_attribute("name", label) if label
      data.each do |child_data|
        element.add_element(convert_json_to_xml(child_data))
      end
      element
    else
      element = REXML::Element.new("node")
      element.add_attribute("type", data.class.name)
      element.add_attribute("name", label) if label
      element.add_text(data.to_s)
      element
    end
  end

  ##############################################################################
  # General handler utility functions
  ##############################################################################

  # This is a template method that is used to escape results values (returned in
  # execute) that would cause the XML to be invalid.  This method is not
  # necessary if values do not contain character that have special meaning in
  # XML (&, ", <, and >), however it is a good practice to use it for all return
  # variable results in case the value could include one of those characters in
  # the future.  This method can be copied and reused between handlers.
  def escape(string)
    # Globally replace characters based on the ESCAPE_CHARACTERS constant
    string.to_s.gsub(/[&"><]/) { |special| ESCAPE_CHARACTERS[special] } if string
  end
  # This is a ruby constant that is used by the escape method
  ESCAPE_CHARACTERS = {'&'=>'&amp;', '>'=>'&gt;', '<'=>'&lt;', '"' => '&quot;'}
end
