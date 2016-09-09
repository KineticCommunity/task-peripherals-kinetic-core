# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class KineticRequestCeSubmissionRetrieveByQueryV1
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
  end

  # The execute method gets called by the task engine when the handler's node is processed. It is
  # responsible for performing whatever action the name indicates.
  # If it returns a result, it will be in a special XML format that the task engine expects. These
  # results will then be available to subsequent tasks in the process.
  def execute
    api_username  = URI.encode(@info_values["api_username"])
    api_password  = @info_values["api_password"]
    api_server    = @info_values["api_server"]
    kapp_slug     = @parameters["kapp_slug"]
    space_slug    = @parameters["space_slug"].empty? ? @info_values["space_slug"] : @parameters["space_slug"]
    form_slug     = @parameters["form_slug"]
    query         = @parameters["query"]

    api_route = "#{api_server}/#{space_slug}/app/api/v1/kapps/#{kapp_slug}/forms/#{form_slug}/submissions" +
                "?include=details,origin,parent,children,descendents,form,type&limit=1&#{query}"

    puts "API ROUTE: #{api_route}"

    resource = RestClient::Resource.new(api_route, { :user => api_username, :password => api_password })

    response = resource.get

    # if the user record did not exist
    if response.nil?
      <<-RESULTS
      <results>
        <result name="ID"></result>
        <result name="Label"></result>
        <result name="Origin"></result>
        <result name="Parent"></result>
        <result name="Submitted At"></result>
        <result name="Type"></result>
        <result name="Updated At"></result>
        <result name="Updated By"></result>
        <result name="Closed At"></result>
        <result name="Core State"></result>
        <result name="Created At"></result>
        <result name="Created By"></result>
        <result name="Form Description"></result>
        <result name="Form Name"></result>
        <result name="Form Notes"></result>
        <result name="Form Slug"></result>
        <result name="Form Status"></result>
      </results>
      RESULTS
    else

      allresults = JSON.parse(response)["submissions"]
      puts "Full RESULTS: #{allresults.inspect}"
      results = allresults[0]
      
      puts "RESULTS: #{results.inspect}"

      if results.nil?
        <<-RESULTS
        <results>
          <result name="ID"></result>
          <result name="Label"></result>
          <result name="Origin"></result>
          <result name="Parent"></result>
          <result name="Submitted At"></result>
          <result name="Type"></result>
          <result name="Updated At"></result>
          <result name="Updated By"></result>
          <result name="Closed At"></result>
          <result name="Core State"></result>
          <result name="Created At"></result>
          <result name="Created By"></result>
          <result name="Form Description"></result>
          <result name="Form Name"></result>
          <result name="Form Notes"></result>
          <result name="Form Slug"></result>
          <result name="Form Status"></result>
        </results>
        RESULTS
      else
        <<-RESULTS
        <results>
          <result name="ID">#{escape(results["id"])}</result>
          <result name="Label">#{escape(results["label"])}</result>
          <result name="Origin">#{escape(results["origin"])}</result>
          <result name="Parent">#{escape(results["parent"])}</result>
          <result name="Submitted At">#{escape(results["submittedAt"])}</result>
          <result name="Type">#{escape(results["type"])}</result>
          <result name="Updated At">#{escape(results["updatedAt"])}</result>
          <result name="Updated By">#{escape(results["updatedBy"])}</result>
          <result name="Closed At">#{escape(results["closedAt"])}</result>
          <result name="Core State">#{escape(results["coreState"])}</result>
          <result name="Created At">#{escape(results["createdAt"])}</result>
          <result name="Created By">#{escape(results["createdBy"])}</result>
          <result name="Form Description">#{escape(results["form"]["description"])}</result>
          <result name="Form Name">#{escape(results["form"]["name"])}</result>
          <result name="Form Notes">#{escape(results["form"]["notes"])}</result>
          <result name="Form Slug">#{escape(results["form"]["slug"])}</result>
          <result name="Form Status">#{escape(results["form"]["status"])}</result>
        </results>
        RESULTS
      end
    end

    rescue RestClient::Exception => error
      raise StandardError, error
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
