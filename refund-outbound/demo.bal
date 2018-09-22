import ballerina/io;function main(string... args) {
    fork {

        worker w0 {
            int endValue = 10;
            int sum;
            foreach i in 1 ... endValue {
                sum = sum + i;
            }
        }       
        worker w1 {
            int i = 23;
            string s = "Colombo";
            io:println("[w1] i: ", i, " s: ", s);
            (i, s) -> fork;
        }
        
        worker w2 {
            float f = 10.344;
            io:println("[w2] f: ", f);
            f -> fork;
        }
    } join (all) (map results) {
        int iW1;
        string sW1;
        (iW1, sW1) = check <(int, string)>results["w1"];
        io:println("[join-block] iW1: ", iW1, " sW1: ", sW1);
        float fW2 = check <float>results["w2"];
        io:println("[join-block] fW2: ", fW2);
    }
}
