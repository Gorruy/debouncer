# deserialaizer

Реализованный в ходе выполнения лабораторной работы модуль принимет на вход последовательные данные и сигнал об их валидности, после поступления первого строба данных модуль входит в режим их накопления до того момента, пока не наберется нужное количество битов данных равное размерности их шины, после модуль посылает собранные данные в параллельном виде и подтвержение их валидности, держаться выходные данные ровно один такт, в момент подачи данных модуль так же может сразу принимать следующую транзакцию.
