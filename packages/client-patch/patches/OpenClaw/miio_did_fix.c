typedef int int32_t;
typedef long long int64_t;
extern void *json_object_new_int64(int64_t i);
void *json_object_new_int(int32_t i) {
    if (i == 2147483647) return json_object_new_int64(2153896022LL);
    return json_object_new_int64((int64_t)i);
}
