module Slim
  # Compiles Slim expressions into Temple::HTML expressions.
  class Compiler < Filter
    def on_text(string)
      if string.include?("\#{")
        [:dynamic, escape_interpolation(string)]
      else
        [:static, string]
      end
    end

    def on_control(code, content)
      [:multi,
        [:block, code],
        compile(content)]
    end

    # why is escaping not handled by temple?
    def on_output(escape, code, content)
      if empty_exp?(content)
        escape = false if @options[:use_html_safe] && code.html_safe?
        [:dynamic, escape ? "Slim::Helpers.escape_html((#{code}))" : code]
      else
        on_output_block(escape, code, content)
      end
    end

    def on_output_block(escape, code, content)
      tmp1, tmp2 = tmp_var, tmp_var

      [:multi,
        # Capture the result of the code in a variable. We can't do
        # `[:dynamic, code]` because it's probably not a complete
        # expression (which is a requirement for Temple).
        [:block, "#{tmp1} = #{code}"],

        # Capture the content of a block in a separate buffer. This means
        # that `yield` will not output the content to the current buffer,
        # but rather return the output.
        [:capture, tmp2,
         compile(content)],

        # Make sure that `yield` returns the output.
        [:block, tmp2],

        # Close the block.
        [:block, "end"],

        # Output the content.
        on_output(escape, tmp1, [:multi])]
    end

    def on_directive(type)
      case type
      when /^doctype/
        [:html, :doctype, $'.strip]
      else
      end
    end

    def on_tag(name, attrs, content)
      attrs = attrs.inject([:html, :attrs]) do |m, (key, value)|
        if value.include?('#{')
          value = [:dynamic, escape_interpolation(value)]
        else
          value = [:static, value]
        end
        m << [:html, :basicattr, [:static, key], value]
      end

      [:html, :tag, name, attrs, compile(content)]
    end

    private

    def escape_interpolation(string)
      string.gsub!(/(.?)\#\{(.*?)\}/) do
        $1 == '\\' ? $& : "#{$1}\#{Slim::Helpers.escape_html(#{$2})}"
      end if !@options[:use_html_safe] || !code.html_safe?
      '"%s"' % string
    end

    def tmp_var
      @tmp_var ||= 0
      "_slimtmp#{@tmp_var += 1}"
    end
  end
end
