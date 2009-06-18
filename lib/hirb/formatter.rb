module Hirb
  # This class is used by the View to format an output into a string. The formatter object looks for an output's class config in config()
  # and if found applies a helper to the output.
  
  class Formatter
    def initialize(additional_config={})
      @config = Util.recursive_hash_merge default_config, additional_config || {}
    end

    # A hash of Ruby class strings mapped to helper config hashes. A helper config hash must have at least a :method or :class option
    # for a helper to be applied to an output. A helper config hash has the following keys:
    # [:ancestor] Boolean which if true causes subclasses of the output class to inherit its config. Defaults to false.
    #             This is used by activerecord classes.
    # [:method] Specifies a global (Kernel) method to do the formatting.
    # [:class] Specifies a class to do the formatting, using its render() class method. The render() method's arguments are the output and
    #          an options hash.
    # [:output_method] Specifies a method or proc to call on output before passing it to a helper. If the output is an array, it's applied
    #                  to every element in the array.
    # [:options] Options to pass the helper method or class.
    # 
    #   Example: {'String'=>{:class=>'Hirb::Helpers::Table', :ancestor=>true, :options=>{:max_width=>180}}}
    def config
      @config
    end

    def config=(value) #:nodoc:
      @config = Util.recursive_hash_merge default_config, value || {}
    end

    # This is the main method of this class. The formatter looks for the first helper in its config for the given output class.
    # If a helper is found, the output is converted by the helper into a string and returned. If not, nil is returned. The options
    # this class takes are a helper config hash as described in config(). If a block is given it's passed along to a helper class.
    def format_output(output, options={}, &block)
      output_class = determine_output_class(output)
      options = Util.recursive_hash_merge(output_class_options(output_class), options)
      output = options[:output_method] ? (output.is_a?(Array) ? output.map {|e| call_output_method(options[:output_method], e) } : 
        call_output_method(options[:output_method], output) ) : output
      args = [output]
      args << options[:options] if options[:options] && !options[:options].empty?
      if options[:method]
        new_output = send(options[:method],*args)
      elsif options[:class] && (view_class = Util.any_const_get(options[:class]))
        new_output = view_class.render(*args, &block)
      end
      new_output
    end

    #:stopdoc:
    def determine_output_class(output)
      if output.is_a?(Array)
        output[0].class
      else
        output.class
      end
    end

    def call_output_method(output_method, output)
      output_method.is_a?(Proc) ? output_method.call(output) : output.send(output_method)
    end

    # Internal view options built from user-defined ones. Options are built by recursively merging options from oldest
    # ancestors to the most recent ones.
    def output_class_options(output_class)
      @cached_config ||= {}
      @cached_config[output_class] ||= 
        begin
          output_ancestors_with_config = output_class.ancestors.map {|e| e.to_s}.select {|e| @config.has_key?(e)}
          @cached_config[output_class] = output_ancestors_with_config.reverse.inject({}) {|h, klass|
            (klass == output_class.to_s || @config[klass][:ancestor]) ? h.update(@config[klass]) : h
          }
        end
      @cached_config[output_class]
    end

    def reset_cached_config
      @cached_config = nil
    end
    
    def cached_config; @cached_config; end

    def default_config
      Views.constants.inject({}) {|h,e|
        output_class = e.to_s.gsub("_", "::")
        if (views_class = Views.const_get(e)) && views_class.respond_to?(:render)
          default_options = views_class.respond_to?(:default_options) ? views_class.default_options : {}
          h[output_class] = default_options.merge({:class=>"Hirb::Views::#{e}"})
        end
        h
      }
    end
    #:startdoc:
  end
end