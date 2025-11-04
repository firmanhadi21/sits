#include <Rcpp.h>
using namespace Rcpp;

//
// Code adapted from ImputeTS R Package
// https://github.com/SteffenMoritz/imputeTS/commit/163f8e645f31f961bddae29e2e94e2044f1a125d
//
struct pow_wrapper {
    public: double operator()(double a, double b) {
        return ::pow(a, b);
    }
};

NumericVector vecpow(const IntegerVector base, const NumericVector exp) {
    NumericVector out(base.size());
    std::transform(base.cbegin(), base.cend(), exp.cbegin(), out.begin(), pow_wrapper());
    return out;
}

// [[Rcpp::export]]
NumericVector C_interp_mean_window_vec(NumericVector& data, int k, String weighting) {
    // If there is less than two NAs, return data as it is.
    if (sum(is_na(data)) < 2) {
        return data;
    }

    Rcpp::NumericVector tempdata = clone(data);
    // Rcpp::NumericVector out = clone(x);

    int n = tempdata.size();

    for (int i = 0; i < n; i++ ) {
        // If Value is NA -> impute it based on selected method
        if (ISNAN(tempdata[i])) {
            int ktemp = k;

            IntegerVector usedIndices = seq(i - ktemp, i + ktemp);

            usedIndices = usedIndices[usedIndices >= 0];
            usedIndices = usedIndices[usedIndices < n];
            NumericVector t = tempdata[usedIndices];

            // Search for at least 2 NA-values
            while (sum(!is_na(t)) < 2) {
                ktemp = ktemp + 1;
                usedIndices = seq(i - ktemp, i + ktemp);
                usedIndices = usedIndices[usedIndices >= 0];
                usedIndices = usedIndices[usedIndices < n];
                t = tempdata[usedIndices];
            }

            if (weighting == "simple") {
                // Calculate mean value
                NumericVector noNAs = wrap(na_omit(t));
                data[i] = mean(noNAs);
            }
            else if(weighting == "linear") {
                // Calculate weights based on indices 1/(distance from current index+1)
                // Set weights where data is NA to 0
                // Sum up all weights (needed later) to norm it
                // Create weighted data (weights*data)
                // Sum up
                NumericVector weightsData = 1 / (abs(usedIndices - i) + 1);
                LogicalVector naCheck = !is_na(t);
                weightsData = weightsData * as<NumericVector>(naCheck);

                double sumWeights = sum(weightsData);
                NumericVector weightedData = (t * weightsData) / sumWeights;
                NumericVector noNAs = wrap(na_omit(weightedData));

                data[i] = sum(noNAs);
            }
            else if (weighting == "exponential") {
                // Calculate weights based on indices 1/ 2 ^ (distance from current index)
                // Set weights where data is NA to 0
                // Sum up all weights (needed later) to norm it
                // Create weighted data (weights*data)
                // Sum up
                NumericVector expo = abs(usedIndices - i);
                IntegerVector base = Rcpp::rep(2, expo.size());
                NumericVector weightsData = 1 / (vecpow(base, expo));
                LogicalVector naCheck = !is_na(t);
                weightsData = weightsData * as<NumericVector>(naCheck);

                double sumWeights = sum(weightsData);
                NumericVector weightedData = (t * weightsData) / sumWeights;
                NumericVector noNAs = wrap(na_omit(weightedData));

                data[i] = sum(noNAs);
            }
            // else {
            //   stop("Wrong input for parameter weighting. Has to be \"simple\",\"linear\" or \"exponential\"." );
            // }
        }
    }

    return data;
}

// [[Rcpp::export]]
NumericMatrix C_interp_mean_window_mat(NumericMatrix& data, int k, String weighting) {
    int nrows = data.nrow();
    int ncols = data.ncol();

    NumericVector vec(ncols);

    for (int i = 0; i < nrows; i++) {
        NumericVector vec = data(i, _);
        data(i, _) = C_interp_mean_window_vec(vec, k, weighting);
    }

    return data;
}
