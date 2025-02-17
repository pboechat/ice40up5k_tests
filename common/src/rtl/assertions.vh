task assert_eq(input integer got, input integer expected, input reg[32*8:1] var_name);
begin
    if (got != expected)
    begin
        $display("[assertions                      ] - T(%9t) - expected: %16s == %d, got: %16s == %d", $time, var_name, expected, var_name, got);
        $stop();
    end
end
endtask

task assert_gt(input integer got, input integer expected, input reg[32*8:1] var_name);
begin
    if (got < expected)
    begin
        $display("[assertions                      ] - T(%9t) - expected: %16s > %d, got: %16s == %d", $time, var_name, expected, var_name, got);
        $stop();
    end
end
endtask