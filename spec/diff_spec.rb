require_relative 'spec_helper'

describe JsonDiff do
  describe "#generate" do
    context "empty patch" do
      it "on hash" do
        subject.generate({}, {}).should == []
      end

      it "on array" do
        subject.generate([], []).should == []
      end
    end

    context "add op" do
      it "on hash member" do
        subject.generate({foo: :bar},
                         {foo: :bar, baz: :qux})
          .should == [{ op: :add, path: "/baz", value: :qux }]
      end

      it "on array element" do
        subject.generate({foo: [:bar, :baz]},
                         {foo: [:bar, :baz, :qux]})
          .should == [{ op: :add, path: "/foo/2", value: :qux }]
      end

      it "on multiple add in array elements" do
        subject.generate({foo: [:bar]},
                         {foo: [:bar, :qux, :baz]})
          .should == [{ op: :add, path: "/foo/1", value: :qux },
                      { op: :add, path: "/foo/2", value: :baz }]
      end

      it "add null elements in array" do
        subject.generate({foo: [:bar]},
                         {foo: [:bar, nil]})
          .should == [{ op: :add, path: "/foo/1", value: nil }]
      end

      it "on nested member object" do
        subject.generate({foo: :bar},
                         {foo: :bar, child: {grandchild: {}}})
          .should == [{ op: :add, path: "/child", value: {grandchild: {}} }]
      end

      it "on more nested member object" do
        subject.generate({child: {grandchild: {foo: :bar}}},
                         {child: {grandchild: {foo: :bar, chuck: :norris}}})
          .should == [{ op: :add, path: "/child/grandchild/chuck", value: :norris }]
      end

      it "on nested object inside arrays" do
        subject.generate({child: [{foo: :bar}]},
                         {child: [{foo: :bar, chuck: :norris}]})
          .should == [{ op: :add, path: '/child/0/chuck', value: :norris}]
      end

      it "on nested array inside arrays" do
        subject.generate({child: [[:foo, :bar]]},
                         {child: [[:foo, :bar, :chuck]]})
          .should == [{ op: :add, path: '/child/0/2', value: :chuck}]
      end
    end

    context "remove op" do
      it "on hash member" do
        subject.generate({foo: :bar, baz: :qux},
                         {foo: :bar})
          .should == [{ op: :remove, path: "/baz"}]
      end

      it "on array element" do
        subject.generate({foo: [:bar, :baz, :qux]},
                         {foo: [:bar, :baz]})
          .should == [{ op: :remove, path: "/foo/2" }]
      end

      it "on multiple remove in array elements" do
        subject.generate({foo: [:bar, :qux, :baz]},
                         {foo: [:bar]})
          .should == [{ op: :remove, path: "/foo/2" },
                      { op: :remove, path: "/foo/1" }]
      end

      it "remove null elements in array" do
        subject.generate({foo: [:bar, nil]},
                         {foo: [:bar]})
          .should == [{ op: :remove, path: "/foo/1" }]
      end
    end

    context "replace op" do
      it "on hash member" do
        subject.generate({foo: :bar, baz: :qux},
                         {foo: :bar, baz: :boo})
          .should == [{ op: :replace, path: "/baz", value: :boo}]
      end

      it "on array element" do
        subject.generate({foo: [:bar, :qux, :baz]},
                         {foo: [:bar, :foo, :baz]})
          .should == [{ op: :replace, path: "/foo/1", value: :foo }]
      end

      it "when type differ from array to hash" do
        subject.generate({foo: [:bar]},
                         {foo: {bar: :foo}})
          .should == [{ op: :replace, path: "/foo", value: {bar: :foo} }]
      end

      it "when type differ from hash to array" do
        subject.generate({foo: {bar: :foo}},
                         {foo: [:bar]})
          .should == [{ op: :replace, path: "/foo", value: [:bar] }]
      end

      it "replace everything" do
        subject.generate({foo: :bar},
                         [:foo])
          .should == [{ op: :replace, path: "", value: [:foo] }]
      end
    end
  end

  # Adapted from hana
  # https://github.com/tenderlove/hana/blob/master/test/test_ietf.rb
  # Copyright (c) 2012 Aaron Patterson
  context "from ietf" do
    TESTDIR = File.dirname File.expand_path __FILE__
    json = File.read File.join TESTDIR, 'json-patch-tests', 'tests.json'
    tests = JSON.parse json
    tests.each_with_index do |test, i|
      next unless test['doc']

      it "#{test['comment'] || i }" do
        pending "disabled" if test['disabled']

        doc = test['doc']
        expected = test['expected']

        if test['error']
          pending "cannot run error test case"
        elsif !expected
          pending "cannot run test case without expectation"
        else
          patch = JSON.parse(subject.generate(doc, expected).to_json)
          hana = Hana::Patch.new patch
          hana.apply(doc).should == expected
        end
      end
    end
  end
end
