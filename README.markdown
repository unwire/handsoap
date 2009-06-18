Handsoap
===

What
---
Handsoap is a library for creating SOAP clients in Ruby.

[Watch a tutorial](http://www.vimeo.com/4813848), showing how to use Handsoap. The final application can be found at: [http://github.com/troelskn/handsoap-example/tree/master](http://github.com/troelskn/handsoap-example/tree/master)

![Handsoap](http://ny-image0.etsy.com/il_430xN.68558416.jpg)

Why
---

Ruby already has a SOAP-client library, [soap4r](http://dev.ctor.org/soap4r), so why create another one?

> Let me summarize SOAP4R: it smells like Java code built on a Monday morning by an EJB coder.
>
> -- [Ruby In Practice: REST, SOAP, WebSphere MQ and SalesForce](http://blog.labnotes.org/2008/01/28/ruby-in-practice-rest-soap-websphere-mq-and-salesforce/)

OK, not entirely fair, but soap4r has problems. It's incomplete and buggy. If you try to use it for any real-world services, you quickly run into compatibility issues. You can get around some of them, if you have control over the service, but you may not always be that lucky. In the end, even if you get it working, it has a bulky un-Rubyish feel to it.

Handsoap tries to do better by taking a minimalistic approach. Instead of a full abstraction layer, it is more like a toolbox with which you can write SOAP bindings. You could think of it as a [ffi](http://c2.com/cgi/wiki?ForeignFunctionInterface) targeting SOAP.

This means that you generally need to do more manual labor in the cases where soap4r would have automated the mapping. It also means that you need to get your hands dirty with wsdl, xsd and other heavyweight specifications. However, it does give you some tools to help you stay sane.

There are several benefits of using Handsoap:

* It supports the entire SOAP specification, all versions (because you have to implement it your self).
* You actually get a sporting chance to debug and fix protocol level bugs.
* It's much faster than soap4r, because it uses fast low-level libraries for xml-parsing and http-communication.

To summarise, soap4r takes an optimistic approach, where Handsoap expects things to fail. If soap4r works for you today, it's probably the better choice. If you find your self strugling with it, Handsoap will offer a more smooth ride. It won't magically fix things for you though.

Handsoap vs. soap4r benchmark
---

Benchmarks are always unfair, but my experiments has placed Handsoap at being approximately double as fast as soap4r. I'd love any suggestions for a more precise measure.

    $ ruby tests/benchmark_test.rb 1000
    Benchmarking 1000 calls ...
                    user     system      total        real
    handsoap    0.750000   0.090000   0.840000 (  1.992437)
    soap4r      2.240000   0.140000   2.380000 (  3.605836)
    ---------------
    Legend:
    The user CPU time, system CPU time, the sum of the user and system CPU times,
    and the elapsed real time. The unit of time is seconds.

SOAP basics
---

SOAP is a protocol that is tunneled through XML over HTTP. Apart from using the technology for transportation, it doesn't have much to do with HTTP. Some times, it hasn't even got much to do with XML either.

A SOAP client basically consists of three parts:

* A http-connectivity layer,
* a mechanism for marshalling native data types to XML,
* and a mechanism for unmarshalling XML to native data types.

The protocol also contains a large and unwieldy specification of how to do the (un)marshalling, which can be used as the basis for automatically mapping to a rich type model. This makes the protocol fitting for .net/Java, but is a huge overhead for a very dynamically typed language such as Ruby. Much of the complexity of clients such as soap4r, is in the parts that tries to use this specification. Handsoap expects you to manually write the code that marshals/unmarshals, thereby bypassing this complexity (or rather - pass it to the programmer)

Handsoap only supports RPC-style SOAP. This seems to be the most common style. It's probably possible to add support for Document-style with little effort, but until I see the need I'm not going there.

The toolbox
---

The Handsoap toolbox consists of the following components.

Handsoap can use either [curb](http://curb.rubyforge.org/) or [httpclient](http://dev.ctor.org/http-access2) for HTTP-connectivity. The former is recommended, and default, but for portability you might choose the latter. You usually don't need to interact at the HTTP-level, but if you do (for example, if you have to use SSL), you can.

For parsing XML, Handsoap uses [Nokogiri](http://github.com/tenderlove/nokogiri/tree/master). While this may become optional in the future, the dependency is a bit tighter. The XML-parser is used internally in Handsoap, as well as by the code that maps from SOAP to Ruby (The code you're writing). Nokogiri is very fast (being based om libxml) and has a polished and stable api.

There is also a library for generating XML, which you'll use when mapping from Ruby to SOAP. It's quite similar to [Builder](http://builder.rubyforge.org/), but is tailored towards being used for writing SOAP-messages. The name of this library is `XmlMason` and it is included/part of Handsoap.

Recommendations
---

###Workflow

1. Find the wsdl for the service you want to consume.

2. Figure out the url for the endpoint, as well as the protocol version. Put this in a config file.
	 * To find the endpoint, look inside the wsdl, for `<soap:address location="..">`

3. Create a service class. Add endpoints and protocol. Alias needed namespace(s).
   * To find the namespace(s), look in the samples from soapUI. It will be imported as `v1`

4. Open the wsdl in [soapUI](http://www.soapui.org/).

5. In soapUI, find a sample request for the method you want to use. Copy+paste the body-part.

6. Create a method in your service class (Use ruby naming convention)

7. Write Ruby-code (using XmlMason) to generate a request that is similar to the example from soapUI. (In your copy+paste buffer)

8. Write Ruby-code to parse the response (a Nokogiri XML-document) into Ruby data types.

9. Write an integration test to verify that your method works as expected. You can use soapUI to [generate a mock-service](http://www.soapui.org/userguide/mock/getting_started.html).

Repeat point 5..9 for each method that you need to use.
Between each iteration, you should refactor shared code into helper functions.

###Configuration

If you use Rails, you should put the endpoint in a constant in the environment file. That way, you can have different endpoints for test/development/production/etc.

If you don't use Rails, it's still a good idea to move this information to a config file.

The configuration could look like this:

    # wsdl: http://example.org/ws/service?WSDL
    EXAMPLE_SERVICE_ENDPOINT = {
      :uri => 'http://example.org/ws/service',
      :version => 2
    }

If you use Rails, you will need to load the gem from the `config/environment.rb` file, using:

    config.gem 'troelskn-handsoap', :lib => 'handsoap', :source => "http://gems.github.com"

###Service class

Put your service in a file under `app/models`. You should extend `Handsoap::Service`.

You need to provide the endpoint and the SOAP version (1.1 or 1.2). If in doubt, use version 2.

A service usually has a namespace for describing the message-body ([RPC/Litteral style](http://www.ibm.com/developerworks/webservices/library/ws-whichwsdl/#N1011F)). You should set this in the `on_create_document` handler.

A typical service looks like the following:

    # -*- coding: utf-8 -*-
    require 'handsoap'

    class Example::FooService < Handsoap::Service
      endpoint EXAMPLE_SERVICE_ENDPOINT
      on_create_document do |doc|
        doc.alias 'wsdl', "http://example.org/ws/spec"
      end
      # public methods
      # todo

      private
      # helpers
      # todo
    end

The above would go in the file `app/models/example/foo_service.rb`

###Integration tests

Since you're writing mappings manually, it's a good idea to write tests that verify that the service works. If you use standard Rails with `Test::Unit`, you should put these in an integration-test.

For the sample service above, you would create a file in `test/integration/example/foo_service.rb`, with the following content:

    # -*- coding: utf-8 -*-
    require 'test_helper'

    # Example::FooService.logger = $stdout

    class Example::FooServiceTest < Test::Unit::TestCase
      def test_update_icon
        icon = { :href => 'http://www.example.com/icon.jpg', :type => 'image/jpeg' }
        result = Example::FooService.update_icon!(icon)
        assert_equal icon.type, result.type
      end
    end

Note the commented-out line. If you set a logger on the service-class, you can see exactly which XML goes forth and back, which is very useful for debugging.

###Methods

You should use Ruby naming-conventions for methods names. If the method has side-effects, you should postfix it with an exclamation.
Repeat code inside the invoke-block, should be refactored out to *builders*, and the response should be parsed with a *parser*.

    def update_icon!(icon)
      response = invoke("wsdl:UpdateIcon") do |message|
        build_icon!(message, icon)
      end
      parse_icon(response.document.xpath('//icon').first)
    end


###Helpers

You'll end up with two kinds of helpers; Ruby->XML transformers (aka. *builders*) and XML->Ruby transformers (aka. *parsers*).
It's recommended that you stick to the following style/naming scheme:

    # icon -> xml
    def build_icon!(message, icon)
      message.add "icon" do |i|
        i.set_attr "href", icon[:href]
        i.set_attr "type", icon[:type]
      end
    end

    # xml -> icon
    def parse_icon(node)
      { :href => node['href'], :type => node['type'] }
    end

or, if you prefer, you can use a class to represent entities:

    # icon -> xml
    def build_icon!(message, icon)
      message.add "icon" do |i|
        i.set_attr "href", icon.href
        i.set_attr "type", icon.type
      end
    end

    # xml -> icon
    def parse_icon(node)
      Icon.new :href => node['href'],
               :type => node['type']
    end

License
---

Copyright: [Unwire A/S](http://www.unwire.dk), 2009

License: [Creative Commons Attribution 2.5 Denmark License](http://creativecommons.org/licenses/by/2.5/dk/deed.en_GB)

___

troelskn@gmail.com - April, 2009