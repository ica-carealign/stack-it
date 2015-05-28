    "[% Object.Name %]" : {
      "Type" : "AWS::CloudFormation::WaitCondition",
      "DependsOn" : "[% Object.Instance %]",
      "Properties" : {
        "Count"   : [% Object.Count %],
        "Handle"  : { "Ref" : "[% Object.WaitHandler %]" },
        "Timeout" : [% Object.Timeout %]
      }
    }
