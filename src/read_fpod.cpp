
/*
 *
 * @author André Moan
 *
 *
*/

#include <Rcpp.h> // for interfacing with R
#include <fstream> // for reading files from the file system
#include <filesystem> // for file_size() and extension()
#include <algorithm> // for std::transform
#include <tuple> // to be able to cleanly return multiple values from functions

bool eof(std::vector<uint8_t>& buf) {
    static const uint8_t eof_code = 255;
    size_t eof_count = std::count(buf.begin(), buf.end(), eof_code);
    return eof_count >= buf.size() -5;
}

template<class T>
T constructInt(const std::vector<uint8_t>& buf, const size_t offset, const size_t size) {
    T res = 0;
    if (offset+size < buf.size()) {
        for (size_t i = 0; i < size; i++) {
            res <<= 8;
            res |= static_cast<T>(buf[offset+i]);
        }
    }
    return res;
}

// parseString: combines length bytes from offset into a string
std::string parseString(const std::vector<uint8_t>& buf, const size_t& offset,
                        const size_t& length) {
    const char* start_ptr = reinterpret_cast<const char*>(buf.data() + offset);
    std::string result(start_ptr, length);
    return result;
}

// getFiletype: returns the upper-case file extension after the dot
const std::string getFiletype(const std::filesystem::path& file) {
    std::filesystem::path f(file);
    std::string ext(f.extension().string().substr(1));

    std::transform(ext.begin(), ext.end(), ext.begin(),
                   [](unsigned char c) { return std::toupper(c); });
    return ext;
}

// getBufSize: returns the header & data buffer sizes based on the file extension
std::tuple<size_t, size_t> getBufsize(const std::string_view ext) {
    size_t header_buf_size;
    size_t data_buf_size;

    if (ext == "CP1") {
        header_buf_size = 360;
        data_buf_size = 10;
    } else if (ext == "CP3") {
        header_buf_size = 720;
        data_buf_size = 40;
    } else {
        header_buf_size = 1024;
        data_buf_size = 16;
    }

    return {header_buf_size, data_buf_size};
}

// getSpeciesFromCode: maps FPOD species code to species groups
std::string getSpeciesFromCode(const uint8_t code, std::string_view ext) {
    static std::unordered_map<uint8_t, std::string> cpod_codes = {
        {0, "NBHF"},
        {1, "NBHF"},
        {2, "OtherCet"},
        {3, "OtherCet"},
        {4, "Unclassed"},
        {5, "Unclassed"},
        {6, "Sonar"},
        {7, "Sonar"}
    };

    static std::unordered_map<uint8_t, std::string> fpod_codes = {
        {0, "NBHF"},
        {1, "OtherCet"},
        {2, "Unclassed"},
        {3, "Sonar"}
    };

    if (ext == "CP3" && code <= 7) {
        return cpod_codes[code];
    } else if (ext == "FP3" && code <= 3) {
        return fpod_codes[code];
    } else {
        return "";
    }

}

struct WavDataChunk {
    std::vector<uint8_t> IPI;
    std::vector<uint8_t> SPL;
};

class WavData {
public:
    int click;
    std::vector<WavDataChunk> chunks;
    WavData(int m_click): click(m_click) {};
};

Rcpp::DataFrame wavToList(std::vector<WavData>& wav_data) {

    using namespace Rcpp;

    size_t estimated_num_records(wav_data.size()*21);
    IntegerVector click_num(estimated_num_records);
    IntegerVector IPI(estimated_num_records);
    IntegerVector SPL(estimated_num_records);
    size_t pos = 0;
    size_t total_records = 0;

    for (auto& wav : wav_data) {
        for (auto it = wav.chunks.rbegin(); it != wav.chunks.rend(); ++it) {
            for (size_t j = 0; j < 7; j++) {
                click_num[pos] = wav.click;
                IPI[pos] = it->IPI[j];
                SPL[pos] = it->SPL[j];
                pos++;
                total_records++;
            };
        }
    }

    // use this to truncate down to actual data size
    IntegerVector filter;
    if (total_records > 0) {
        filter = seq(0, total_records-1);
    }

    return DataFrame::create(
        Named("click_no") = click_num[filter],
        Named("IPI") = IPI[filter],
        Named("SPL") = SPL[filter]
    );
}

class FPODData {
public:
    // click data:
    Rcpp::IntegerVector min;
    Rcpp::IntegerVector microsec;
    Rcpp::IntegerVector click_no;
    Rcpp::IntegerVector ncyc;
    Rcpp::IntegerVector pkat;
    Rcpp::IntegerVector clk_ipi_range;
    Rcpp::IntegerVector ipi_pre_max;
    Rcpp::IntegerVector ipi_at_max;
    Rcpp::IntegerVector khz;
    Rcpp::IntegerVector amp_at_max;
    Rcpp::IntegerVector amp_reversals;
    Rcpp::NumericVector duration;
    Rcpp::LogicalVector has_wav;

    // train data (if CP3/FP3):
    Rcpp::IntegerVector train_id;
    Rcpp::CharacterVector species;
    Rcpp::IntegerVector quality_level;
    Rcpp::LogicalVector echo;

    // wave data
    std::vector<WavData> wav_data;

    // environmental data
    std::vector<int> temp_deg_c;
    std::vector<int> pod_angle;
    std::vector<int> bat1;
    std::vector<int> bat2;

    Rcpp::List& header;
    int pic_code{0};
    int fgpa_code{0};
    int last_click{0};

    FPODData(std::uintmax_t max_clicks, Rcpp::List& m_header) :
        min(max_clicks),
        microsec(max_clicks),
        click_no(Rcpp::seq(1, max_clicks)),
        ncyc(max_clicks),
        pkat(max_clicks),
        clk_ipi_range(max_clicks),
        ipi_pre_max(max_clicks),
        ipi_at_max(max_clicks),
        khz(max_clicks),
        amp_at_max(max_clicks),
        amp_reversals(max_clicks),
        duration(max_clicks),
        has_wav(max_clicks),
        train_id(max_clicks),
        species(max_clicks),
        quality_level(max_clicks),
        echo(max_clicks),
        header(m_header) {
    };

    Rcpp::List toList() {

        using namespace Rcpp;

        // empty vector, so we can return an empty data.frame if no clicks were found.
        IntegerVector filter;

        // use this to truncate down to actual data size
        if (last_click > -1) {
            filter = seq(0, last_click);
        }

        List ret;

        ret.push_back(header, "header");

        DataFrame clicks = DataFrame::create(
            Named("minute") = min[filter],
            Named("microsec") = microsec[filter],
            Named("click_no") = click_no[filter],
            Named("train_id") = train_id[filter],
            Named("species") = species[filter],
            Named("quality_level") = quality_level[filter],
            Named("echo") = echo[filter],
            Named("ncyc") = ncyc[filter],
            Named("pkat") = pkat[filter],
            Named("clk_ipi_range") = clk_ipi_range[filter],
            Named("ipi_pre_max") = ipi_pre_max[filter],
            Named("ipi_at_max") = ipi_at_max[filter],
            Named("khz") = khz[filter],
            Named("amp_at_max") = amp_at_max[filter],
            Named("amp_reversals") = amp_reversals[filter],
            Named("duration") = duration[filter],
            Named("has_wav") = has_wav[filter]
        );

        if (temp_deg_c.size() > 0) {

            DataFrame env = DataFrame::create(
                Named("minute") = seq(1, temp_deg_c.size()),
                Named("degC") = wrap(temp_deg_c),
                Named("bat1v") = wrap(bat1),
                Named("bat2v") = wrap(bat2)
            );

            ret.push_back(env, "env");
        }

        ret.push_back(wavToList(wav_data), "wav");

        ret.push_back(clicks, "clicks");

        return ret;
    }
};

Rcpp::List getFPODHeader(std::vector<uint8_t>& buf, std::string_view ext) {
    Rcpp::List header;
    header["pod_id"] = 100 * buf[3] + buf[4];
    header["first_logged_min"] = constructInt<int32_t>(buf, 256, 4);
    header["last_logged_min"] = constructInt<int32_t>(buf, 260, 4);
    header["water_depth"] = (buf[131] << 8) + buf[132];
    header["deployment_depth"] = (buf[129] << 8) + buf[130];
    header["lat_text"] = parseString(buf, 133, 11);
    header["lon_text"] = parseString(buf, 145, 11);
    header["location_text"] =parseString(buf, 157, 30);
    header["notes_text"] = parseString(buf, 188, 43);
    header["gmt_text"] = parseString(buf, 232, 11);

    int fpga_ver = buf[39] << 8 | buf[40];
    header["pic_ver"] = buf[37];
    header["fpga_ver"] = fpga_ver;

    if (fpga_ver > 0) {
        header["extended_amps"] = true;
    } else {
        header["extended_amps"] = false;
    }

    if (ext == "FP3") {
        header["clicks_in_fp1"] = constructInt<int64_t>(buf, 231, 8);
    }
    return header;
}

Rcpp::List getCPODHeader(std::vector<uint8_t>& buf, std::string_view ext) {
    Rcpp::List header;
    header["pod_id"] = parseString(buf, 164, 4);
    header["first_logged_min"] = constructInt<int32_t>(buf, 256, 4);
    header["last_logged_min"] = constructInt<int32_t>(buf, 260, 4);
    header["water_depth"] = (buf[31] << 8) | buf[32];
    header["deployment_depth"] = (buf[29] << 8) | buf[30];
    header["lat_text"] = parseString(buf, 13, 8);
    header["lon_text"] = parseString(buf, 21, 8);
    header["location_text"] = parseString(buf, 33, 31);
    header["notes_text"] = parseString(buf, 211, 50);

    if (ext == "CP3") {
        header["clicks_in_cp1"] = constructInt<uint32_t>(buf, 128, 4);
    }
    return header;
}

int getFPODData(std::ifstream& fid,
                std::string_view ext,
                size_t data_buf_size,
                FPODData& dat) {

    using namespace Rcpp;

    std::vector<uint8_t> buf;
    buf.resize(data_buf_size);

    // starting at -1 makes the logic inside the loop below a lot nicer
    int current_click = -1;
    int current_min = -1;
    int pic_ver = as<Rcpp::IntegerVector>(dat.header["pic_ver"])[0];
    //int fpga_ver = as<Rcpp::IntegerVector>(dat.header["fpga_ver"])[0];

    while (1) {

        if (!fid.read(reinterpret_cast<char*>(&buf[0]), data_buf_size)) {
            break;
        } else {

            size_t bytesActuallyRead = fid.gcount();

            if (bytesActuallyRead < data_buf_size) {
                break;
            }

            if (buf[0] < 184) {

                // click data
                current_click++;
                dat.min[current_click] = current_min;
                double microsec_d = static_cast<double>(constructInt<uint32_t>(buf, 0, 3) / 200.0 * 1000.0);
                dat.microsec[current_click] = static_cast<int>(microsec_d);

                dat.ncyc[current_click] = buf[3];
                dat.pkat[current_click] = (buf[4] & 0xF0) >> 4;
                if ((buf[4] & 0xF) == 15) {
                    dat.clk_ipi_range[current_click] = 65;
                } else if ((buf[4] & 0x8) == 8) {
                    dat.clk_ipi_range[current_click] = (((buf[4] & 0x7) + 1) << 3);
                } else {
                    dat.clk_ipi_range[current_click] = (buf[4] & 0x7);
                }
                dat.ipi_pre_max[current_click] = buf[5] + 1;
                dat.ipi_at_max[current_click] = buf[6] + 1;
                dat.amp_at_max[current_click] = std::max(static_cast<uint8_t>(2), buf[10]);
                dat.amp_reversals[current_click] = buf[13] & 15;
                dat.duration[current_click] = ((buf[13] & 240) * 16 + buf[14])/5;

            } else if (buf[0] == 249) {

                // click train data precedes next click
                dat.train_id[current_click+1] = buf[15]; // 1 to 255
                dat.species[current_click+1] = getSpeciesFromCode((buf[14] >> 2) & 3, ext);
                dat.quality_level[current_click+1] = buf[14] & 3;
                dat.echo[current_click+1] = (buf[14] & 32) == 32 ? TRUE : FALSE;

                //spGood[current_click+1] = (buf[14] & 64) == 64 ? TRUE : FALSE;
                //rateGood[current_click+1] = (buf[14] & 128) == 128 ? TRUE : FALSE;

            } else if (buf[0] == 250) {

                // wav data precedes next click
                if (dat.has_wav[current_click+1] != TRUE) {
                    dat.has_wav[current_click+1] = TRUE;
                    // +2 since we're talking about click numbers, not indices,
                    // and since we're also talking about the next click
                    dat.wav_data.emplace_back(WavData(current_click + 2));
                }

                dat.wav_data.back().chunks.emplace_back();
                for (int pos = 12; pos >= 0; pos -= 2) {
                    dat.wav_data.back().chunks.back().IPI.push_back(buf[pos+1]);
                    dat.wav_data.back().chunks.back().SPL.push_back(buf[pos+2]);
                }

            } else if (buf[0] == 254) {

                current_min++;

                dat.temp_deg_c.push_back(static_cast<int>(buf[7]));

                if (pic_ver < 28 && buf[11] == 0 && buf[13]) {
                    dat.bat1.push_back(buf[12]);
                    dat.bat2.push_back(buf[13]);
                } else {
                    dat.bat1.push_back(buf[11]);
                    dat.bat2.push_back(buf[12]);
                }

            }
        }
    }
    dat.last_click = current_click;
    return current_click;
}

int getCPODData(std::ifstream& fid,
                       std::string_view ext,
                       size_t data_buf_size,
                       FPODData& dat) {

    using namespace Rcpp;

    std::vector<uint8_t> buf;
    buf.resize(data_buf_size);

    // starting at -1 makes the logic inside the loop below a lot nicer
    int current_click = -1;
    int current_min = -1;
    int file_ends = 0;
    size_t last_byte = data_buf_size -1;

    while (1) {

        if (!fid.read(reinterpret_cast<char*>(&buf[0]), data_buf_size)) {
            break;
        } else {
            size_t bytesActuallyRead = fid.gcount();

            if (bytesActuallyRead < data_buf_size) {
                break;
            }

            // In CP3 files, the end of data is indicated by two consecutive
            // data chunks where all values are 255.
            if (eof(buf)) {
                if (++file_ends == 2) {
                    break;
                }
                //continue;
            } else {
                file_ends = 0;
            }

            if (buf[last_byte] != 254) {

                // click data
                current_click++;
                dat.min[current_click] = current_min;
                double microsec_d = static_cast<double>(constructInt<uint32_t>(buf, 0, 3) / 200.0 * 1000.0);
                dat.microsec[current_click] = static_cast<int>(microsec_d);

                dat.ncyc[current_click] = buf[3];
                dat.khz[current_click] = buf[5];
                dat.amp_at_max[current_click] = buf[5];

                if (buf[5] > 0) {
                    dat.duration[current_click] = static_cast<double>(buf[3]) / static_cast<double>(buf[5]);
                }

                if (ext == "CP3") {
                    dat.train_id[current_click] = buf[39];
                    dat.species[current_click] = getSpeciesFromCode(buf[36] >> 3, ext);
                    dat.quality_level[current_click] = buf[36] & 3;
                }

            } else if (buf[last_byte] == 254) {
                current_min++;
            }
        }
    }
    dat.last_click = current_click-1;
    return current_click-1;
}

// [[Rcpp::export]]
Rcpp::List readFPOD(const std::string file) {

    using namespace Rcpp;
    std::string basename(std::filesystem::path(file).filename().string());
    std::string ext(getFiletype(file));
    auto [header_buf_size, data_buf_size] = getBufsize(ext);
    std::ifstream fid(file.c_str(), std::ios::binary);

    if (!fid.is_open()) {
        stop("Unable to open file %s", basename);
    }

    // get an estimate of the maximum possible number of clicks
    // in reality, it will always be less than this, because of train/wav data
    // being interspersed among clicks
    std::uintmax_t max_clicks = (std::filesystem::file_size(file) - header_buf_size) / data_buf_size;
    std::vector<uint8_t> buf(header_buf_size);

    if (!fid.read(reinterpret_cast<char*>(&buf[0]), header_buf_size)) {
        stop("Unable to read from file");
    }

    // read header data
    List header;
    List data;
    FPODData fpod_data(max_clicks, header);

    if (ext == "CP1" || ext == "CP3") {
        header = getCPODHeader(buf, ext);
        fpod_data.last_click = getCPODData(fid, ext, data_buf_size, fpod_data);
    } else if (ext == "FP1" || ext == "FP3") {
        header = getFPODHeader(buf, ext);
        fpod_data.last_click = getFPODData(fid, ext, data_buf_size, fpod_data);
    } else {
        stop("Unknown file type: %s", ext);
    }

    fid.close();

    header["filename"] = CharacterVector(file);
    return fpod_data.toList();
    //return List::create();
}



